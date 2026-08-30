import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

const APP_ORIGIN = "http://127.0.0.1:3000";
const APP_HOST = "127.0.0.1:3000";
const MAILPIT_ORIGIN = "http://127.0.0.1:55324";
const AUTH_COOKIE_NAME = "rebuy-g2-a1-e2a-auth-token";
const RESEND_COOLDOWN_MS = 1000;

class HarnessError extends Error {
  constructor(stage) {
    super(stage);
    this.stage = stage;
  }
}

function fail(stage) {
  throw new HarnessError(stage);
}

function makeSyntheticEmail() {
  return `e2a-${randomUUID().replaceAll("-", "").slice(0, 18)}@rebuy.test`;
}

function makeNegativeEmail() {
  return `e2a-${randomUUID().replaceAll("-", "").slice(0, 18)}@example.invalid`;
}

function assertFiniteBody(body, expected) {
  assert.deepEqual(body, expected);
}

async function fetchJson(stage, url, init) {
  let response;
  try {
    response = await fetch(url, init);
  } catch {
    fail(stage);
  }

  let body;
  try {
    body = await response.json();
  } catch {
    fail(stage);
  }

  return { response, body };
}

function appHeaders() {
  return {
    Accept: "application/json",
    "Content-Type": "application/json",
    Host: APP_HOST,
    Origin: APP_ORIGIN,
  };
}

async function postOtp(stage, payload) {
  return fetchJson(stage, `${APP_ORIGIN}/api/auth/email-otp`, {
    method: "POST",
    headers: appHeaders(),
    body: JSON.stringify(payload),
  });
}

function responseCookieHeader(response) {
  const getSetCookie = response.headers.getSetCookie;
  const setCookies = typeof getSetCookie === "function"
    ? getSetCookie.call(response.headers)
    : [response.headers.get("set-cookie")].filter(Boolean);
  return setCookies.map((value) => value.split(";", 1)[0]).join("; ");
}

function hasCookie(cookieHeader, name) {
  return cookieHeader.split("; ").some((item) => item.startsWith(`${name}=`));
}

async function searchMailpit(email) {
  const query = encodeURIComponent(`to:${email}`);
  let response;
  try {
    response = await fetch(`${MAILPIT_ORIGIN}/api/v1/search?query=${query}`, {
      headers: { Accept: "application/json" },
    });
  } catch {
    fail("mailpit_search");
  }

  if (!response.ok) {
    fail("mailpit_search");
  }

  let body;
  try {
    body = await response.json();
  } catch {
    fail("mailpit_search");
  }

  return Array.isArray(body?.messages) ? body.messages : [];
}

async function readMailpitToken(messageId) {
  let response;
  try {
    response = await fetch(`${MAILPIT_ORIGIN}/api/v1/message/${encodeURIComponent(messageId)}`, {
      headers: { Accept: "application/json" },
    });
  } catch {
    fail("mailpit_message");
  }

  if (!response.ok) {
    fail("mailpit_message");
  }

  let body;
  try {
    body = await response.json();
  } catch {
    fail("mailpit_message");
  }

  const text = [body?.Text, body?.HTML, body?.text, body?.html]
    .filter((value) => typeof value === "string")
    .join("\n");
  const match = text.match(/\b\d{6}\b/);
  if (!match) {
    fail("mailpit_token");
  }
  return match[0];
}

async function waitForNewOtp(email, seenIds = new Set()) {
  for (let attempt = 0; attempt < 24; attempt += 1) {
    const messages = await searchMailpit(email);
    for (const message of messages) {
      const id = message?.ID ?? message?.Id ?? message?.id;
      if (typeof id === "string" && !seenIds.has(id)) {
        seenIds.add(id);
        return { token: await readMailpitToken(id), seenIds };
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  fail("mailpit_timeout");
}

async function getSession(stage, cookieHeader) {
  const headers = { Accept: "application/json", Host: APP_HOST };
  if (cookieHeader) {
    headers.Cookie = cookieHeader;
  }
  return fetchJson(stage, `${APP_ORIGIN}/api/auth/session`, {
    method: "GET",
    headers,
    cache: "no-store",
  });
}

async function requestOtp(email, stage = "request") {
  const result = await postOtp(stage, { action: "request", email });
  assert.equal(result.response.status, 200);
  assertFiniteBody(result.body, { status: "otp_sent" });
  console.log("REQUEST_PASS");
}

async function verifyOtp(email, token, stage) {
  return postOtp(stage, { action: "verify", email, token });
}

async function exerciseMainFlow() {
  const anonymous = await getSession("anonymous_session");
  assert.equal(anonymous.response.status, 401);
  assertFiniteBody(anonymous.body, { status: "anonymous" });
  console.log("ANONYMOUS_SESSION_PASS");

  const wrongCookie = await getSession("wrong_cookie", "rebuy-other-project-auth-token=opaque");
  assert.equal(wrongCookie.response.status, 401);
  assertFiniteBody(wrongCookie.body, { status: "anonymous" });
  console.log("WRONG_COOKIE_PASS");

  const email = makeSyntheticEmail();
  await requestOtp(email);
  const firstMail = await waitForNewOtp(email);
  console.log("MAIL_CAPTURE_PASS");

  const wrongToken = firstMail.token === "000000" ? "111111" : "000000";
  const wrong = await verifyOtp(email, wrongToken, "wrong_otp");
  assert.equal(wrong.response.status, 422);
  assertFiniteBody(wrong.body, { status: "error", code: "verify_failed" });
  console.log("WRONG_OTP_PASS");

  const verified = await verifyOtp(email, firstMail.token, "verify");
  assert.equal(verified.response.status, 200);
  assertFiniteBody(verified.body, { status: "verified" });
  const cookieHeader = responseCookieHeader(verified.response);
  assert.equal(hasCookie(cookieHeader, AUTH_COOKIE_NAME), true);
  console.log("VERIFY_PASS");

  const authenticated = await getSession("authenticated_session", cookieHeader);
  assert.equal(authenticated.response.status, 200);
  assertFiniteBody(authenticated.body, { status: "authenticated" });
  console.log("SESSION_PASS");

  const replay = await verifyOtp(email, firstMail.token, "replay");
  assert.equal(replay.response.status, 422);
  assertFiniteBody(replay.body, { status: "error", code: "verify_failed" });
  console.log("REPLAY_PASS");

  await new Promise((resolve) => setTimeout(resolve, RESEND_COOLDOWN_MS + 100));
  const resend = await postOtp(email, { action: "resend", email });
  assert.equal(resend.response.status, 200);
  assertFiniteBody(resend.body, { status: "otp_sent" });
  const resentMail = await waitForNewOtp(email, firstMail.seenIds);
  assert.equal(typeof resentMail.token, "string");
  console.log("RESEND_PASS");
}

async function exerciseOldOtpSemantics() {
  const email = makeSyntheticEmail();
  await requestOtp(email, "resend_semantics_request");
  const beforeResend = await waitForNewOtp(email);

  await new Promise((resolve) => setTimeout(resolve, RESEND_COOLDOWN_MS + 100));
  const resend = await postOtp("resend_semantics_resend", { action: "resend", email });
  assert.equal(resend.response.status, 200);
  assertFiniteBody(resend.body, { status: "otp_sent" });
  const afterResend = await waitForNewOtp(email, beforeResend.seenIds);

  if (beforeResend.token === afterResend.token) {
    console.log("OLD_OTP_SEMANTICS_NOT_PROVEN");
    return;
  }

  const oldOtp = await verifyOtp(email, beforeResend.token, "old_otp");
  assert.equal(oldOtp.response.status, 422);
  assertFiniteBody(oldOtp.body, { status: "error", code: "verify_failed" });
  console.log("OLD_OTP_REJECTED_PASS");

  const currentOtp = await verifyOtp(email, afterResend.token, "resend_verify");
  assert.equal(currentOtp.response.status, 200);
  assertFiniteBody(currentOtp.body, { status: "verified" });
  console.log("RESEND_VERIFY_PASS");
}

async function exerciseNegativeEmail() {
  const email = makeNegativeEmail();
  const before = await searchMailpit(email);
  assert.equal(before.length, 0);

  const result = await postOtp("negative_email", { action: "request", email });
  assert.equal(result.response.status, 400);
  assertFiniteBody(result.body, { status: "error", code: "invalid_request" });
  await new Promise((resolve) => setTimeout(resolve, 500));
  const after = await searchMailpit(email);
  assert.equal(after.length, 0);
  console.log("NEGATIVE_EMAIL_PASS");
}

try {
  await exerciseMainFlow();
  await exerciseOldOtpSemantics();
  await exerciseNegativeEmail();
  console.log("E2A_RUNTIME_PASS");
} catch (error) {
  console.error(`E2A_RUNTIME_FAILED:${error instanceof HarnessError ? error.stage : "assertion"}`);
  process.exitCode = 1;
}
