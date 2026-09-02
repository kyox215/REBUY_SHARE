import { execFile as execFileCallback } from "node:child_process";
import { randomUUID } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import { createClient } from "@supabase/supabase-js";

import {
  hasMinimumAmrEpochSeparation,
  selectAllowedPublicKey,
} from "./p2l-amr-preflight-config.mjs";

const execFile = promisify(execFileCallback);
const WORKTREE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const SUPABASE_HOME = "/private/tmp/rebuy-p2l-supabase-home";
const LOCAL_API_ORIGIN = "http://127.0.0.1:55321";
const MAILPIT_ORIGIN = "http://127.0.0.1:55324";
const MAILPIT_POLL_ATTEMPTS = 24;
const MAILPIT_POLL_DELAY_MS = 500;
const FETCH_TIMEOUT_MS = 10_000;
const REFRESH_SEPARATION_POLL_MS = 100;
const REFRESH_SEPARATION_TIMEOUT_MS = 10_000;
const MAX_AMR_AGE_SECONDS = 600;
const MAX_AMR_FUTURE_SECONDS = 60;
const SYNTHETIC_EMAIL_PATTERN = /^p2l-[0-9a-f]{20}@rebuy\.test$/;

class PreflightFailure extends Error {
  constructor(category) {
    super(category);
    this.category = category;
  }
}

function fail(category) {
  throw new PreflightFailure(category);
}

function emit(category, passed, ageSeconds) {
  const suffix = passed ? "PASS" : "FAIL";
  const age = Number.isFinite(ageSeconds) ? ` age_seconds=${Math.trunc(ageSeconds)}` : "";
  console.log(`${category}_${suffix}${age}`);
}

function check(category, passed, ageSeconds) {
  emit(category, passed, ageSeconds);
  if (!passed) {
    fail(category);
  }
}

function cliEnvironment() {
  return {
    ...process.env,
    SUPABASE_TELEMETRY_DISABLED: "1",
    SUPABASE_HOME,
  };
}

function isLocalApiUrl(value) {
  try {
    const parsed = new URL(value);
    return (
      parsed.protocol === "http:" &&
      parsed.hostname === "127.0.0.1" &&
      parsed.port === "55321" &&
      (parsed.pathname === "" || parsed.pathname === "/") &&
      parsed.search === "" &&
      parsed.hash === ""
    );
  } catch {
    return false;
  }
}

async function readLocalConfig() {
  let stdout;
  try {
    ({ stdout } = await execFile(
      "supabase",
      ["status", "-o", "json"],
      {
        cwd: WORKTREE_ROOT,
        env: cliEnvironment(),
        maxBuffer: 1024 * 1024,
      },
    ));
  } catch {
    check("STATUS", false);
  }

  let status;
  try {
    status = JSON.parse(stdout);
  } catch {
    check("STATUS", false);
  }

  const apiUrl = status?.API_URL;
  const publicKey = selectAllowedPublicKey(status);
  const valid = isLocalApiUrl(apiUrl) && typeof publicKey === "string";
  check("STATUS", valid);

  return {
    apiUrl: new URL(apiUrl).origin,
    publicKey,
  };
}

function makeSyntheticEmail() {
  return `p2l-${randomUUID().replaceAll("-", "").slice(0, 20)}@rebuy.test`;
}

function assertSyntheticEmail(email) {
  check("EMAIL_GENERATED", SYNTHETIC_EMAIL_PATTERN.test(email));
}

function isExpectedOrigin(response, expectedOrigin) {
  try {
    return !response.redirected && new URL(response.url).origin === expectedOrigin;
  } catch {
    return false;
  }
}

async function fetchJson(url, init, expectedOrigin) {
  let response;
  try {
    response = await fetch(url, {
      ...init,
      redirect: "manual",
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
  } catch {
    return null;
  }

  if (!isExpectedOrigin(response, expectedOrigin)) {
    return null;
  }

  try {
    return { response, body: await response.json() };
  } catch {
    return null;
  }
}

async function searchMailpit(email) {
  const query = encodeURIComponent(`to:${email}`);
  const result = await fetchJson(
    `${MAILPIT_ORIGIN}/api/v1/search?query=${query}`,
    { headers: { Accept: "application/json" } },
    MAILPIT_ORIGIN,
  );

  if (!result?.response.ok || !Array.isArray(result.body?.messages)) {
    fail("MAILPIT_SEARCH");
  }

  return result.body.messages;
}

async function readMailpitOtp(messageId) {
  const result = await fetchJson(
    `${MAILPIT_ORIGIN}/api/v1/message/${encodeURIComponent(messageId)}`,
    { headers: { Accept: "application/json" } },
    MAILPIT_ORIGIN,
  );

  if (!result?.response.ok) {
    fail("MAILPIT_MESSAGE");
  }

  const body = result.body;
  const text = [body?.Text, body?.HTML, body?.text, body?.html]
    .filter((value) => typeof value === "string")
    .join("\n");
  const match = text.match(/\b\d{6}\b/);
  if (!match) {
    fail("MAILPIT_OTP");
  }

  return match[0];
}

async function waitForMailpitOtp(email) {
  const seenIds = new Set();
  for (let attempt = 0; attempt < MAILPIT_POLL_ATTEMPTS; attempt += 1) {
    const messages = await searchMailpit(email);
    for (const message of messages) {
      const messageId = message?.ID ?? message?.Id ?? message?.id;
      if (typeof messageId === "string" && !seenIds.has(messageId)) {
        seenIds.add(messageId);
        return readMailpitOtp(messageId);
      }
    }
    await new Promise((resolvePromise) => setTimeout(resolvePromise, MAILPIT_POLL_DELAY_MS));
  }
  fail("MAILPIT_TIMEOUT");
}

async function callAuth(category, operation) {
  try {
    return await operation();
  } catch {
    check(category, false);
  }
}

function decodeJwtPayload(accessToken, category) {
  const parts = accessToken.split(".");
  if (parts.length !== 3) {
    check(category, false);
  }

  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      check(category, false);
    }
    return payload;
  } catch {
    check(category, false);
  }
}

function validateInitialClaims(accessToken, email) {
  const claims = decodeJwtPayload(accessToken, "INITIAL_CLAIMS");
  const firstAmr = Array.isArray(claims.amr) ? claims.amr[0] : undefined;
  check("INITIAL_AMR_METHOD", firstAmr?.method === "otp");

  const timestamp = firstAmr?.timestamp;
  const timestampNumeric =
    typeof timestamp === "number" &&
    Number.isSafeInteger(timestamp) &&
    timestamp > 0;
  check("INITIAL_AMR_TIMESTAMP_NUMERIC", timestampNumeric);

  const ageSeconds = Math.floor(Date.now() / 1000) - timestamp;
  check(
    "INITIAL_AMR_RECENCY",
    ageSeconds <= MAX_AMR_AGE_SECONDS && ageSeconds >= -MAX_AMR_FUTURE_SECONDS,
    ageSeconds,
  );
  check("INITIAL_IS_ANONYMOUS_FALSE", claims.is_anonymous === false);

  const signedEmail = claims.email;
  const emailNormalized =
    typeof signedEmail === "string" &&
    signedEmail === signedEmail.trim().toLowerCase() &&
    signedEmail === email &&
    SYNTHETIC_EMAIL_PATTERN.test(signedEmail);
  check("INITIAL_EMAIL_NORMALIZED", emailNormalized);

  return { timestamp };
}

function validateRefreshedClaims(accessToken, email, initialTimestamp) {
  const claims = decodeJwtPayload(accessToken, "REFRESH_CLAIMS");
  const firstAmr = Array.isArray(claims.amr) ? claims.amr[0] : undefined;
  check("REFRESH_AMR_METHOD", firstAmr?.method === "otp");

  const timestamp = firstAmr?.timestamp;
  const timestampNumeric =
    typeof timestamp === "number" &&
    Number.isSafeInteger(timestamp) &&
    timestamp > 0;
  check("REFRESH_AMR_TIMESTAMP_NUMERIC", timestampNumeric);
  check("REFRESH_AMR_TIMESTAMP_UNCHANGED", timestamp === initialTimestamp);
  check("REFRESH_IS_ANONYMOUS_FALSE", claims.is_anonymous === false);

  const signedEmail = claims.email;
  const emailNormalized =
    typeof signedEmail === "string" &&
    signedEmail === signedEmail.trim().toLowerCase() &&
    signedEmail === email &&
    SYNTHETIC_EMAIL_PATTERN.test(signedEmail);
  check("REFRESH_EMAIL_NORMALIZED", emailNormalized);
}

async function waitForRefreshAmrSeparation(initialTimestamp) {
  const deadline = Date.now() + REFRESH_SEPARATION_TIMEOUT_MS;

  while (Date.now() <= deadline) {
    const currentEpochSeconds = Math.floor(Date.now() / 1000);
    if (hasMinimumAmrEpochSeparation(currentEpochSeconds, initialTimestamp)) {
      check("REFRESH_AMR_TIME_SEPARATION", true);
      return;
    }

    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) {
      break;
    }
    await new Promise((resolvePromise) =>
      setTimeout(resolvePromise, Math.min(REFRESH_SEPARATION_POLL_MS, remainingMs)),
    );
  }

  check("REFRESH_AMR_TIME_SEPARATION", false);
}

async function getVerifiedUser(supabase, accessToken, category) {
  const result = await callAuth(category, () => supabase.auth.getUser(accessToken));
  const valid = !!result && !result.error && !!result.data?.user;
  check(category, valid);
  return result.data.user;
}

async function runPreflight() {
  const { apiUrl, publicKey } = await readLocalConfig();
  const email = makeSyntheticEmail();
  assertSyntheticEmail(email);

  const supabase = createClient(apiUrl, publicKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });

  const request = await callAuth("OTP_REQUEST", () =>
    supabase.auth.signInWithOtp({
      email,
      options: { shouldCreateUser: true },
    }),
  );
  check("OTP_REQUEST", !!request && !request.error);

  const otp = await waitForMailpitOtp(email);
  emit("MAILPIT_CAPTURE", true);

  const verification = await callAuth("OTP_VERIFY", () =>
    supabase.auth.verifyOtp({ email, token: otp, type: "email" }),
  );
  const initialSession = verification?.data?.session;
  const verified =
    !!verification &&
    !verification.error &&
    typeof initialSession?.access_token === "string" &&
    typeof initialSession?.refresh_token === "string";
  check("OTP_VERIFY", verified);

  await getVerifiedUser(supabase, initialSession.access_token, "INITIAL_GET_USER");
  const initialClaims = validateInitialClaims(initialSession.access_token, email);

  await waitForRefreshAmrSeparation(initialClaims.timestamp);

  const refreshed = await callAuth("REFRESH_SESSION", () =>
    supabase.auth.refreshSession({ refresh_token: initialSession.refresh_token }),
  );
  const refreshedSession = refreshed?.data?.session;
  const refreshedOk =
    !!refreshed &&
    !refreshed.error &&
    typeof refreshedSession?.access_token === "string" &&
    typeof refreshedSession?.refresh_token === "string";
  check("REFRESH_SESSION", refreshedOk);
  check(
    "REFRESH_ACCESS_TOKEN_CHANGED",
    refreshedSession.access_token !== initialSession.access_token,
  );

  await getVerifiedUser(supabase, refreshedSession.access_token, "REFRESH_GET_USER");
  validateRefreshedClaims(
    refreshedSession.access_token,
    email,
    initialClaims.timestamp,
  );
}

try {
  await runPreflight();
  emit("P2L_PREFLIGHT", true);
} catch (error) {
  if (!(error instanceof PreflightFailure)) {
    emit("UNEXPECTED", false);
  }
  emit("P2L_PREFLIGHT", false);
  process.exitCode = 1;
}
