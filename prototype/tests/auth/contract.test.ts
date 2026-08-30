import assert from "node:assert/strict";
import { test } from "node:test";

import {
  AUTH_CALLBACK_CODE_MAX_LENGTH,
  AUTH_CALLBACK_ERROR_MESSAGES,
  decideAuthCallback,
  isAuthCallbackErrorCode,
} from "../../lib/auth/callback";
import { handleAuthCallback } from "../../lib/auth/callback-route";
import {
  EMAIL_OTP_LENGTH,
  SYNTHETIC_EMAIL_DOMAIN,
  runEmailOtp,
  type EmailOtpAuthAdapter,
} from "../../lib/auth/email-otp";
import {
  EMAIL_OTP_MAX_BODY_BYTES,
  EMAIL_OTP_APP_HOST,
  EMAIL_OTP_APP_ORIGIN,
  handleEmailOtpRequest,
} from "../../lib/auth/email-otp-route";
import {
  EMAIL_OTP_RESEND_COOLDOWN_MS,
  isRateLimitedAuthError,
} from "../../lib/auth/email-otp";
import { resolveSessionStatus } from "../../lib/auth/session";
import {
  getSupabaseConfig,
  isAllowedSupabasePublicKey,
  LOCAL_SUPABASE_URL,
  REBUY_AUTH_COOKIE_NAME,
  REBUY_AUTH_COOKIE_OPTIONS,
} from "../../lib/supabase/config";
import { createServerCookieMethods } from "../../lib/supabase/cookies";
import { normalizeSafeNext } from "../../lib/auth/redirect";

test("normalizes safe same-origin destinations", () => {
  const acceptedDestinations = [
    "/",
    "/catalog?query=usb-c#results",
    "/products/charger%20stand",
    "/products//related",
    "/商品/详情",
  ];

  for (const destination of acceptedDestinations) {
    assert.equal(normalizeSafeNext(destination), destination);
  }
});

test("rejects external, deeply encoded, and unsafe destinations", () => {
  const rejectedDestinations = [
    "https://outside.invalid/products",
    "//outside.invalid/products",
    "\\\\outside.invalid\\products",
    "/\\\\outside.invalid/products",
    "/%2f%2foutside.invalid/products",
    "/%252f%252foutside.invalid/products",
    "/safe%5coutside",
    "/safe%255coutside",
    "/safe%00value",
    "/safe%2500value",
    "/safe\nvalue",
    "/safe\tvalue",
    "/safe\u00a0value",
    "/safe\u3000value",
    "/safe%E2%80%83value",
    "/safe%E2%80%8Bvalue",
    "/catalog/../account",
    "/catalog/%2e%2e/account",
    "/catalog/%252e%252e/account",
    "/%2525252f%2525252foutside.invalid/products",
    "/%2525252525252f%2525252525252foutside.invalid/products",
    `/${"a".repeat(2048)}`,
    "/%invalid",
    "/%2",
  ];

  for (const destination of rejectedDestinations) {
    assert.equal(normalizeSafeNext(destination), "/", destination);
  }
});

test("handles provider errors and unknown UI error codes without exchange", async () => {
  let exchangeCalls = 0;
  const providerError = await decideAuthCallback({
    code: "provider-code-that-must-not-leak",
    error: "access_denied",
    errorDescription: "provider-internal-description",
    next: "/account",
    exchange: async () => {
      exchangeCalls += 1;
      return { error: null };
    },
  });

  assert.deepEqual(providerError, {
    kind: "error",
    code: "provider_error",
    next: "/account",
  });
  assert.equal(exchangeCalls, 0);
  assert.equal(
    JSON.stringify(providerError).includes("provider-internal-description"),
    false,
  );
  assert.equal(isAuthCallbackErrorCode("unknown_code"), false);
  assert.equal(
    Object.prototype.hasOwnProperty.call(AUTH_CALLBACK_ERROR_MESSAGES, "unknown_code"),
    false,
  );
});

test("returns missing-code for an unsafe destination without exchange", async () => {
  let exchangeCalls = 0;
  const missingCode = await decideAuthCallback({
    next: "https://outside.invalid",
    exchange: async () => {
      exchangeCalls += 1;
      return { error: null };
    },
  });

  assert.deepEqual(missingCode, {
    kind: "error",
    code: "missing_code",
    next: "/",
  });
  assert.equal(exchangeCalls, 0);
});

test("rejects invalid callback codes before exchange", async () => {
  const invalidCodes = [
    " leading-space",
    "trailing-space ",
    "internal space",
    "opaque\ncode",
    "opaque\u2028code",
    "opaque\u200bcode",
    "a".repeat(AUTH_CALLBACK_CODE_MAX_LENGTH + 1),
  ];

  for (const code of invalidCodes) {
    let exchangeCalls = 0;
    let exchangedCode: string | undefined;
    const decision = await decideAuthCallback({
      code,
      exchange: async (value) => {
        exchangeCalls += 1;
        exchangedCode = value;
        return { error: null };
      },
    });

    assert.deepEqual(decision, {
      kind: "error",
      code: "invalid_code",
      next: "/",
    });
    assert.equal(exchangeCalls, 0);
    assert.equal(exchangedCode, undefined);
  }

  for (const code of [undefined, "", "   "]) {
    let exchangeCalls = 0;
    const decision = await decideAuthCallback({
      code,
      exchange: async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    });

    assert.deepEqual(decision, {
      kind: "error",
      code: "missing_code",
      next: "/",
    });
    assert.equal(exchangeCalls, 0);
  }
});

test("passes a valid maximum-length code exactly once", async () => {
  const validCode = "a".repeat(AUTH_CALLBACK_CODE_MAX_LENGTH);
  let exchangeCalls = 0;
  let exchangedCode = "";
  const decision = await decideAuthCallback({
    code: validCode,
    exchange: async (code) => {
      exchangeCalls += 1;
      exchangedCode = code;
      return { error: null };
    },
  });

  assert.deepEqual(decision, { kind: "success", next: "/" });
  assert.equal(exchangeCalls, 1);
  assert.equal(exchangedCode, validCode);
});

test("exchanges a valid code exactly once", async () => {
  let exchangeCalls = 0;
  let exchangedCode = "";
  const success = await decideAuthCallback({
    code: "opaque-auth-code",
    next: "/account/orders?tab=open",
    exchange: async (code) => {
      exchangeCalls += 1;
      exchangedCode = code;
      return { error: null };
    },
  });

  assert.deepEqual(success, {
    kind: "success",
    next: "/account/orders?tab=open",
  });
  assert.equal(exchangeCalls, 1);
  assert.equal(exchangedCode, "opaque-auth-code");
});

test("maps exchange errors and invalid results to finite codes", async () => {
  let exchangeCalls = 0;
  const failedExchange = await decideAuthCallback({
    code: "opaque-auth-code",
    exchange: async () => {
      exchangeCalls += 1;
      return { error: new Error("provider-raw-error") };
    },
  });
  const nullExchange = await decideAuthCallback({
    code: "opaque-auth-code",
    exchange: async () => {
      exchangeCalls += 1;
      return null;
    },
  });
  const undefinedExchange = await decideAuthCallback({
    code: "opaque-auth-code",
    exchange: async () => {
      exchangeCalls += 1;
      return undefined;
    },
  });

  assert.deepEqual(failedExchange, {
    kind: "error",
    code: "exchange_failed",
    next: "/",
  });
  assert.deepEqual(nullExchange, {
    kind: "error",
    code: "exchange_failed",
    next: "/",
  });
  assert.deepEqual(undefinedExchange, {
    kind: "error",
    code: "exchange_failed",
    next: "/",
  });
  assert.equal(JSON.stringify(failedExchange).includes("provider-raw-error"), false);
  assert.equal(exchangeCalls, 3);
});

test("maps thrown exchange failures without returning raw errors", async () => {
  let exchangeCalls = 0;
  const thrownExchange = await decideAuthCallback({
    code: "opaque-auth-code",
    exchange: async () => {
      exchangeCalls += 1;
      throw new Error("raw-exception-that-must-not-leak");
    },
  });

  assert.deepEqual(thrownExchange, {
    kind: "error",
    code: "exchange_error",
    next: "/",
  });
  assert.equal(
    JSON.stringify(thrownExchange).includes("raw-exception-that-must-not-leak"),
    false,
  );
  assert.equal(exchangeCalls, 1);
});

test("handles a successful callback request with a same-origin redirect", async () => {
  let exchangeCalls = 0;
  let exchangedCode = "";
  const response = await handleAuthCallback(
    new Request(
      "https://rebuy.local/auth/callback?code=opaque-auth-code&next=%2Faccount%2Forders%3Ftab%3Dopen",
    ),
    async (code) => {
      exchangeCalls += 1;
      exchangedCode = code;
      return { error: null };
    },
  );
  const location = new URL(response.headers.get("Location") ?? "");

  assert.equal(response.status, 303);
  assert.equal(location.origin, "https://rebuy.local");
  assert.equal(location.pathname, "/account/orders");
  assert.equal(location.search, "?tab=open");
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(response.headers.get("Referrer-Policy"), "no-referrer");
  assert.equal(exchangeCalls, 1);
  assert.equal(exchangedCode, "opaque-auth-code");
  assert.equal(location.toString().includes("opaque-auth-code"), false);
  assert.equal(location.toString().includes("provider-internal-description"), false);
});

test("redirects callback failures with finite errors and no exchange", async () => {
  const cases = [
    {
      url: "https://rebuy.local/auth/callback?code=opaque-code&error=access_denied&error_description=provider-internal-description",
      code: "provider_error",
    },
    {
      url: "https://rebuy.local/auth/callback?code=%20opaque-code",
      code: "invalid_code",
    },
    {
      url: "https://rebuy.local/auth/callback",
      code: "missing_code",
    },
  ] as const;

  for (const item of cases) {
    let exchangeCalls = 0;
    const response = await handleAuthCallback(
      new Request(item.url),
      async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    );
    const location = new URL(response.headers.get("Location") ?? "");

    assert.equal(response.status, 303);
    assert.equal(location.origin, "https://rebuy.local");
    assert.equal(location.pathname, "/account/login");
    assert.equal(location.searchParams.get("auth_error"), item.code);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    assert.equal(response.headers.get("Referrer-Policy"), "no-referrer");
    assert.equal(exchangeCalls, 0);
    assert.equal(location.toString().includes("opaque-code"), false);
    assert.equal(location.toString().includes("provider-internal-description"), false);
  }
});

test("applies a final origin check to the route decision", async () => {
  const response = await handleAuthCallback(
    new Request("https://rebuy.local/auth/callback?code=opaque-code"),
    async () => ({ error: null }),
    async () => ({
      kind: "success",
      next: "https://outside.invalid/private",
    }),
  );
  const location = new URL(response.headers.get("Location") ?? "");

  assert.equal(response.status, 303);
  assert.equal(location.origin, "https://rebuy.local");
  assert.equal(location.pathname, "/account/login");
  assert.equal(location.searchParams.get("auth_error"), "exchange_error");
  assert.equal(location.toString().includes("outside.invalid"), false);
});

const syntheticEmail = `e2a-contract@${SYNTHETIC_EMAIL_DOMAIN}`;
const validOtp = "7".repeat(EMAIL_OTP_LENGTH);

function makeAdapter(overrides: Partial<EmailOtpAuthAdapter> = {}) {
  return {
    signInWithOtp: async () => ({ error: null }),
    verifyOtp: async () => ({ error: null }),
    ...overrides,
  } satisfies EmailOtpAuthAdapter;
}

function makeJsonRequest(value: unknown, headers: Record<string, string> = {}) {
  return new Request("http://127.0.0.1:3000/api/auth/email-otp", {
    method: "POST",
    headers: {
      Origin: "http://127.0.0.1:3000",
      Host: "127.0.0.1:3000",
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(value),
  });
}

async function responseJson(response: Response) {
  return (await response.json()) as Record<string, unknown>;
}

test("rejects invalid email OTP input without calling the adapter", async () => {
  let calls = 0;
  const adapter = makeAdapter({
    signInWithOtp: async () => {
      calls += 1;
      return { error: null };
    },
    verifyOtp: async () => {
      calls += 1;
      return { error: null };
    },
  });
  const invalidInputs = [
    { action: "request", email: "person@example.invalid" },
    { action: "request", email: syntheticEmail, extra: true },
    { action: "verify", email: syntheticEmail, token: "1".repeat(EMAIL_OTP_LENGTH - 1) },
    { action: "verify", email: syntheticEmail, token: validOtp, extra: true },
    null,
  ];

  for (const input of invalidInputs) {
    assert.deepEqual(await runEmailOtp(input, adapter), {
      kind: "error",
      code: "invalid_input",
    });
  }

  assert.equal(calls, 0);
});

test("normalizes a valid email and calls request and resend exactly once", async () => {
  const signInCalls: Array<{ email: string; shouldCreateUser: true }> = [];
  const adapter = makeAdapter({
    signInWithOtp: async ({ email, options }) => {
      signInCalls.push({ email, shouldCreateUser: options.shouldCreateUser });
      return { error: null };
    },
  });

  const request = await runEmailOtp(
    { action: "request", email: `  E2A-CONTRACT@${SYNTHETIC_EMAIL_DOMAIN.toUpperCase()} ` },
    adapter,
  );
  const resend = await runEmailOtp(
    { action: "resend", email: syntheticEmail },
    adapter,
  );

  assert.deepEqual(request, { kind: "success", action: "request", status: "otp_sent" });
  assert.deepEqual(resend, { kind: "success", action: "resend", status: "otp_sent" });
  assert.deepEqual(signInCalls, [
    { email: syntheticEmail, shouldCreateUser: true },
    { email: syntheticEmail, shouldCreateUser: true },
  ]);
});

test("verifies a six digit OTP once and maps wrong or replayed OTP errors", async () => {
  const verifyCalls: Array<{ email: string; token: string; type: "email" }> = [];
  const adapter = makeAdapter({
    verifyOtp: async (credentials) => {
      verifyCalls.push(credentials);
      return verifyCalls.length === 1
        ? { error: null }
        : { error: new Error("provider-otp-error-that-must-not-leak") };
    },
  });

  const verified = await runEmailOtp(
    { action: "verify", email: syntheticEmail, token: validOtp },
    adapter,
  );
  const replayed = await runEmailOtp(
    { action: "verify", email: syntheticEmail, token: validOtp },
    adapter,
  );

  assert.deepEqual(verified, { kind: "success", action: "verify", status: "verified" });
  assert.deepEqual(replayed, { kind: "error", action: "verify", code: "verify_failed" });
  assert.deepEqual(verifyCalls, [
    { email: syntheticEmail, token: validOtp, type: "email" },
    { email: syntheticEmail, token: validOtp, type: "email" },
  ]);
  assert.equal(JSON.stringify(replayed).includes("provider-otp-error-that-must-not-leak"), false);
});

test("maps thrown request and verify failures to finite codes", async () => {
  const requestFailure = await runEmailOtp(
    { action: "request", email: syntheticEmail },
    makeAdapter({
      signInWithOtp: async () => {
        throw new Error("provider-request-error-that-must-not-leak");
      },
    }),
  );
  const verifyFailure = await runEmailOtp(
    { action: "verify", email: syntheticEmail, token: validOtp },
    makeAdapter({
      verifyOtp: async () => {
        throw new Error("provider-verify-error-that-must-not-leak");
      },
    }),
  );

  assert.deepEqual(requestFailure, { kind: "error", action: "request", code: "request_failed" });
  assert.deepEqual(verifyFailure, { kind: "error", action: "verify", code: "verify_failed" });
  assert.equal(JSON.stringify(requestFailure).includes("provider-request-error-that-must-not-leak"), false);
  assert.equal(JSON.stringify(verifyFailure).includes("provider-verify-error-that-must-not-leak"), false);
});

test("enforces same-origin JSON and body gates before creating an adapter", async () => {
  let factoryCalls = 0;
  const createAdapter = async () => {
    factoryCalls += 1;
    return makeAdapter();
  };
  const cases = [
    {
      request: new Request("http://127.0.0.1:3000/api/auth/email-otp", {
        method: "POST",
        headers: {
          Host: "127.0.0.1:3000",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ action: "request", email: syntheticEmail }),
      }),
      status: 403,
      code: "origin_not_allowed",
    },
    {
      request: makeJsonRequest({ action: "request", email: syntheticEmail }, { Origin: "http://outside.invalid" }),
      status: 403,
      code: "origin_not_allowed",
    },
    {
      request: new Request("http://127.0.0.1:3000/api/auth/email-otp", {
        method: "POST",
        headers: {
          Origin: "http://127.0.0.1:3000",
          Host: "127.0.0.1:3000",
          "Content-Type": "text/plain",
        },
        body: "{}",
      }),
      status: 415,
      code: "unsupported_media_type",
    },
    {
      request: makeJsonRequest({ action: "request", email: syntheticEmail }, {
        "Content-Length": String(EMAIL_OTP_MAX_BODY_BYTES + 1),
      }),
      status: 413,
      code: "body_too_large",
    },
    {
      request: makeJsonRequest({ action: "request", email: syntheticEmail }, { "Content-Length": "not-a-size" }),
      status: 400,
      code: "invalid_request",
    },
    {
      request: new Request("http://127.0.0.1:3000/api/auth/email-otp", {
        method: "POST",
        headers: {
          Origin: "http://127.0.0.1:3000",
          Host: "127.0.0.1:3000",
          "Content-Type": "application/json",
        },
        body: "{",
      }),
      status: 400,
      code: "invalid_request",
    },
    {
      request: makeJsonRequest({ action: "request", email: "person@example.invalid" }),
      status: 400,
      code: "invalid_request",
    },
  ] as const;

  for (const item of cases) {
    const response = await handleEmailOtpRequest(item.request, createAdapter);
    assert.equal(response.status, item.status);
    assert.deepEqual(await responseJson(response), { status: "error", code: item.code });
  }

  assert.equal(factoryCalls, 0);
});

test("returns finite route results and preserves no-store headers", async () => {
  let factoryCalls = 0;
  let signInCalls = 0;
  let verifyCalls = 0;
  const createAdapter = async () => {
    factoryCalls += 1;
    return makeAdapter({
      signInWithOtp: async () => {
        signInCalls += 1;
        return { error: null };
      },
      verifyOtp: async () => {
        verifyCalls += 1;
        return { error: null };
      },
    });
  };

  const requestResponse = await handleEmailOtpRequest(
    makeJsonRequest({ action: "request", email: syntheticEmail }),
    createAdapter,
  );
  const verifyResponse = await handleEmailOtpRequest(
    makeJsonRequest({ action: "verify", email: syntheticEmail, token: validOtp }),
    createAdapter,
  );

  assert.equal(requestResponse.status, 200);
  assert.deepEqual(await responseJson(requestResponse), { status: "otp_sent" });
  assert.equal(verifyResponse.status, 200);
  assert.deepEqual(await responseJson(verifyResponse), { status: "verified" });
  assert.equal(requestResponse.headers.get("Cache-Control"), "no-store");
  assert.equal(requestResponse.headers.get("Referrer-Policy"), "no-referrer");
  assert.equal(requestResponse.headers.get("X-Content-Type-Options"), "nosniff");
  assert.equal(factoryCalls, 2);
  assert.equal(signInCalls, 1);
  assert.equal(verifyCalls, 1);
});

test("does not expose provider errors or factory failures through the route", async () => {
  const providerFailure = await handleEmailOtpRequest(
    makeJsonRequest({ action: "request", email: syntheticEmail }),
    async () => makeAdapter({
      signInWithOtp: async () => ({ error: new Error("raw-provider-message") }),
    }),
  );
  const factoryFailure = await handleEmailOtpRequest(
    makeJsonRequest({ action: "verify", email: syntheticEmail, token: validOtp }),
    async () => {
      throw new Error("raw-factory-message");
    },
  );

  const providerBody = await responseJson(providerFailure);
  const factoryBody = await responseJson(factoryFailure);
  assert.equal(providerFailure.status, 502);
  assert.deepEqual(providerBody, { status: "error", code: "request_failed" });
  assert.equal(factoryFailure.status, 500);
  assert.deepEqual(factoryBody, { status: "error", code: "server_error" });
  assert.equal(JSON.stringify(providerBody).includes("raw-provider-message"), false);
  assert.equal(JSON.stringify(factoryBody).includes("raw-factory-message"), false);
});

function encodeJwtPart(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

const legacyAnonFixture = [
  encodeJwtPart({ alg: "HS256", typ: "JWT" }),
  encodeJwtPart({ role: "anon", iss: "http://127.0.0.1:55321/auth/v1" }),
  "fixture-signature",
].join(".");
const legacyPrivilegedRole = ["service", "role"].join("_");
const legacyPrivilegedFixture = [
  encodeJwtPart({ alg: "HS256", typ: "JWT" }),
  encodeJwtPart({ role: legacyPrivilegedRole }),
  "fixture-signature",
].join(".");

function withSupabaseEnv<T>(url: string | undefined, key: string | undefined, callback: () => T) {
  const previousUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const previousKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (url === undefined) {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
  } else {
    process.env.NEXT_PUBLIC_SUPABASE_URL = url;
  }
  if (key === undefined) {
    delete process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  } else {
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = key;
  }

  try {
    return callback();
  } finally {
    if (previousUrl === undefined) {
      delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    } else {
      process.env.NEXT_PUBLIC_SUPABASE_URL = previousUrl;
    }
    if (previousKey === undefined) {
      delete process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    } else {
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = previousKey;
    }
  }
}

test("accepts only the canonical local URL and anonymous public key forms", () => {
  assert.equal(isAllowedSupabasePublicKey("sb_publishable_test_fixture"), true);
  assert.equal(isAllowedSupabasePublicKey(legacyAnonFixture), true);
  assert.deepEqual(
    withSupabaseEnv(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture", () => getSupabaseConfig()),
    {
      url: LOCAL_SUPABASE_URL,
      publishableKey: "sb_publishable_test_fixture",
    },
  );
  assert.deepEqual(
    withSupabaseEnv(LOCAL_SUPABASE_URL, legacyAnonFixture, () => getSupabaseConfig()),
    {
      url: LOCAL_SUPABASE_URL,
      publishableKey: legacyAnonFixture,
    },
  );
});

test("rejects URL variants, privileged keys, unknown keys, and malformed JWTs", () => {
  const rejectedUrls = [
    "http://localhost:55321/",
    "http://127.0.0.1:55321",
    "http://127.0.0.1:55321/rest/v1/",
    "http://127.0.0.1:55321/?query=1",
    "http://127.0.0.1:55321/#fragment",
    "http://user:pass@127.0.0.1:55321/",
    "https://127.0.0.1:55321/",
    "http://127.0.0.1:55322/",
  ];

  for (const url of rejectedUrls) {
    assert.throws(
      () => withSupabaseEnv(url, "sb_publishable_test_fixture", () => getSupabaseConfig()),
      /Local Supabase is not configured/,
      url,
    );
  }

  const rejectedKeys = [
    ["sb", "secret", "test_fixture"].join("_"),
    legacyPrivilegedFixture,
    "not-a-public-key",
    "eyJhbGciOiJIUzI1NiJ9.invalid.signature",
    " sb_publishable_test_fixture",
  ];

  for (const key of rejectedKeys) {
    assert.equal(isAllowedSupabasePublicKey(key), false, key);
    assert.throws(
      () => withSupabaseEnv(LOCAL_SUPABASE_URL, key, () => getSupabaseConfig()),
      /Local Supabase is not configured/,
      key,
    );
  }
});

test("keeps the Rebuy cookie name fixed and makes route writes strict", () => {
  assert.equal(REBUY_AUTH_COOKIE_NAME, "rebuy-g2-a1-e2a-auth-token");
  assert.equal(REBUY_AUTH_COOKIE_OPTIONS.name, REBUY_AUTH_COOKIE_NAME);

  const writes: string[] = [];
  const store = {
    getAll: () => [{ name: REBUY_AUTH_COOKIE_NAME, value: "opaque" }],
    set: (name: string) => writes.push(name),
  };
  const readonly = createServerCookieMethods(store, "readonly");
  const strict = createServerCookieMethods(
    {
      getAll: store.getAll,
      set: () => {
        throw new Error("cookie write failure");
      },
    },
    "strict",
  );

  assert.deepEqual(readonly.getAll(), [{ name: REBUY_AUTH_COOKIE_NAME, value: "opaque" }]);
  assert.doesNotThrow(() =>
    readonly.setAll!([{ name: REBUY_AUTH_COOKIE_NAME, value: "opaque", options: {} }], {}),
  );
  assert.deepEqual(writes, [REBUY_AUTH_COOKIE_NAME]);
  assert.throws(
    () => strict.setAll!([{ name: REBUY_AUTH_COOKIE_NAME, value: "opaque", options: {} }], {}),
    /cookie write failure/,
  );
});

test("resolves authenticated, anonymous, and error session states without leaking claims", async () => {
  assert.deepEqual(
    await resolveSessionStatus({ getClaims: async () => ({ data: { claims: { sub: "user" } } }) }),
    { status: "authenticated" },
  );
  assert.deepEqual(
    await resolveSessionStatus({ getClaims: async () => ({ data: { claims: null }, error: null }) }),
    { status: "anonymous" },
  );
  const rawError = "raw session provider error";
  const failed = await resolveSessionStatus({
    getClaims: async () => ({ data: null, error: new Error(rawError) }),
  });
  const thrown = await resolveSessionStatus({
    getClaims: async () => {
      throw new Error(rawError);
    },
  });
  assert.deepEqual(failed, { status: "error" });
  assert.deepEqual(thrown, { status: "error" });
  assert.equal(JSON.stringify(failed).includes(rawError), false);
});

test("maps rate limits to a finite error and keeps the resend cooldown aligned to local config", async () => {
  assert.equal(EMAIL_OTP_RESEND_COOLDOWN_MS, 1000);
  assert.equal(isRateLimitedAuthError({ status: 429, message: "raw provider text" }), true);
  assert.equal(isRateLimitedAuthError({ code: "over_email_send_rate_limit" }), true);

  const outcome = await runEmailOtp(
    { action: "resend", email: syntheticEmail },
    makeAdapter({
      signInWithOtp: async () => ({
        error: { status: 429, message: "raw provider text that must not leak" },
      }),
    }),
  );
  assert.deepEqual(outcome, { kind: "error", action: "resend", code: "rate_limited" });
  assert.equal(JSON.stringify(outcome).includes("raw provider text"), false);
});

test("cancels an over-limit streaming body before creating an adapter", async () => {
  let cancelled = false;
  let factoryCalls = 0;
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array(EMAIL_OTP_MAX_BODY_BYTES + 1));
    },
    cancel() {
      cancelled = true;
    },
  });
  const request = new Request("http://127.0.0.1:3000/api/auth/email-otp", {
    method: "POST",
    headers: {
      Origin: EMAIL_OTP_APP_ORIGIN,
      Host: EMAIL_OTP_APP_HOST,
      "Content-Type": "application/json",
    },
    body,
    duplex: "half",
  } as RequestInit);

  const response = await handleEmailOtpRequest(request, async () => {
    factoryCalls += 1;
    return makeAdapter();
  });

  assert.equal(response.status, 413);
  assert.deepEqual(await responseJson(response), { status: "error", code: "body_too_large" });
  assert.equal(cancelled, true);
  assert.equal(factoryCalls, 0);
});

test("rejects invalid UTF-8 before creating an adapter", async () => {
  let factoryCalls = 0;
  const request = new Request("http://127.0.0.1:3000/api/auth/email-otp", {
    method: "POST",
    headers: {
      Origin: EMAIL_OTP_APP_ORIGIN,
      Host: EMAIL_OTP_APP_HOST,
      "Content-Type": "application/json",
    },
    body: new Uint8Array([0xc3, 0x28]),
  });
  const response = await handleEmailOtpRequest(request, async () => {
    factoryCalls += 1;
    return makeAdapter();
  });

  assert.equal(response.status, 400);
  assert.deepEqual(await responseJson(response), { status: "error", code: "invalid_request" });
  assert.equal(factoryCalls, 0);
});

test("requires the exact fixed app origin and host", async () => {
  const rejectedRequests = [
    makeJsonRequest({ action: "request", email: syntheticEmail }, { Host: "localhost:3000" }),
    makeJsonRequest({ action: "request", email: syntheticEmail }, { Host: "127.0.0.1:3000.evil" }),
    makeJsonRequest({ action: "request", email: syntheticEmail }, { Origin: "http://localhost:3000" }),
    makeJsonRequest({ action: "request", email: syntheticEmail }, { Origin: "http://127.0.0.1:3000/" }),
    new Request("http://localhost:3000/api/auth/email-otp", {
      method: "POST",
      headers: {
        Origin: EMAIL_OTP_APP_ORIGIN,
        Host: EMAIL_OTP_APP_HOST,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ action: "request", email: syntheticEmail }),
    }),
  ];
  let factoryCalls = 0;

  for (const request of rejectedRequests) {
    const response = await handleEmailOtpRequest(request, async () => {
      factoryCalls += 1;
      return makeAdapter();
    });
    assert.equal(response.status, 403);
    assert.deepEqual(await responseJson(response), {
      status: "error",
      code: "origin_not_allowed",
    });
  }

  assert.equal(factoryCalls, 0);
});
