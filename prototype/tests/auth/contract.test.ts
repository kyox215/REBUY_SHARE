import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { resolve } from "node:path";
import { test } from "node:test";
import type { CookieOptions } from "@supabase/ssr";

const requireFromPrototype = createRequire(resolve(process.cwd(), "package.json"));
const { createServerClient } = requireFromPrototype("@supabase/ssr") as typeof import("@supabase/ssr");

import {
  AUTH_CALLBACK_CODE_MAX_LENGTH,
  AUTH_CALLBACK_ERROR_MESSAGES,
  decideAuthCallback,
  isAuthCallbackErrorCode,
} from "../../lib/auth/callback";
import {
  AUTH_CALLBACK_APP_HOST,
  AUTH_CALLBACK_APP_ORIGIN,
  AUTH_CALLBACK_PATH,
  handleAuthCallback,
  handleAuthCallbackForMode,
} from "../../lib/auth/callback-route";
import {
  LOCAL_APP_HOST,
  LOCAL_APP_ORIGIN,
  isCanonicalLocalAppRequest,
} from "../../lib/auth/app-origin";
import {
  exchangeAndPersistSession,
  getRebuyPkceFlowSlotCookieName,
  isValidPkceFlowId,
  REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME,
  REBUY_PKCE_FLOW_INDEX_COOKIE_NAME,
  createEphemeralExchangeCookieMethods,
} from "../../lib/auth/callback-session";
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
  handleEmailOtpRequestForMode,
} from "../../lib/auth/email-otp-route";
import {
  EMAIL_OTP_RESEND_COOLDOWN_MS,
  isRateLimitedAuthError,
} from "../../lib/auth/email-otp";
import { resolveSessionStatus } from "../../lib/auth/session";
import { handleSessionRequest } from "../../lib/auth/session-route";
import {
  createAuthCallbackGetHandler,
  createEmailOtpPostHandler,
  createLogoutPostHandler,
  createSessionGetHandler,
} from "../../lib/auth/route-composition";
import {
  AUTH_RUNTIME_MODES,
  resolveAuthRuntimeMode,
} from "../../lib/auth/runtime-mode-core";
import { createAppHealthResponse } from "../../lib/health/app";
import { createAppHealthGetHandler } from "../../lib/health/route-composition";
import {
  handleLogoutRequest,
  handleLogoutRequestForMode,
  LOGOUT_APP_HOST,
  LOGOUT_APP_ORIGIN,
} from "../../lib/auth/logout";
import {
  isAllowedSupabasePublicKey,
  LOCAL_SUPABASE_URL,
  REBUY_AUTH_COOKIE_NAME,
  REBUY_AUTH_COOKIE_OPTIONS,
  SupabaseConfigError,
  validateSupabaseConfig,
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
      `${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-auth-code&next=%2Faccount%2Forders%3Ftab%3Dopen`,
      { headers: { Host: AUTH_CALLBACK_APP_HOST } },
    ),
    async (code) => {
      exchangeCalls += 1;
      exchangedCode = code;
      return { error: null };
    },
  );
  const location = new URL(response.headers.get("Location") ?? "");

  assert.equal(response.status, 303);
  assert.equal(location.origin, AUTH_CALLBACK_APP_ORIGIN);
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
      url: `${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code&error=access_denied&error_description=provider-internal-description`,
      code: "provider_error",
    },
    {
      url: `${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=%20opaque-code`,
      code: "invalid_code",
    },
    {
      url: `${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}`,
      code: "missing_code",
    },
  ] as const;

  for (const item of cases) {
    let exchangeCalls = 0;
    const response = await handleAuthCallback(
      new Request(item.url, { headers: { Host: AUTH_CALLBACK_APP_HOST } }),
      async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    );
    const location = new URL(response.headers.get("Location") ?? "");

    assert.equal(response.status, 303);
    assert.equal(location.origin, AUTH_CALLBACK_APP_ORIGIN);
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
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    async () => ({ error: null }),
    async () => ({
      kind: "success",
      next: "https://outside.invalid/private",
    }),
  );
  const location = new URL(response.headers.get("Location") ?? "");

  assert.equal(response.status, 303);
  assert.equal(location.origin, AUTH_CALLBACK_APP_ORIGIN);
  assert.equal(location.pathname, "/account/login");
  assert.equal(location.searchParams.get("auth_error"), "exchange_error");
  assert.equal(location.toString().includes("outside.invalid"), false);
});

test("rejects callback URL, Host, path, and forwarded-header spoofing before exchange", async () => {
  const rejectedRequests = [
    new Request("http://localhost:3000/auth/callback?code=opaque-code", {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    new Request("http://127.0.0.1:3001/auth/callback?code=opaque-code", {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    {
      url: "http://spoof@127.0.0.1:3000/auth/callback?code=opaque-code",
      headers: new Headers({ Host: AUTH_CALLBACK_APP_HOST }),
    } as unknown as Request,
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}/auth/callback/extra?code=opaque-code`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
      headers: { Host: "localhost:3000" },
    }),
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
      headers: {
        Host: AUTH_CALLBACK_APP_HOST,
        "X-Forwarded-Host": "outside.invalid",
      },
    }),
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
      headers: {
        Host: AUTH_CALLBACK_APP_HOST,
        Forwarded: "host=outside.invalid",
      },
    }),
  ];
  let exchangeCalls = 0;

  for (const request of rejectedRequests) {
    const response = await handleAuthCallback(request, async () => {
      exchangeCalls += 1;
      return { error: null };
    });
    const location = new URL(response.headers.get("Location") ?? "");

    assert.equal(response.status, 303);
    assert.equal(location.origin, AUTH_CALLBACK_APP_ORIGIN);
    assert.equal(location.pathname, "/account/login");
    assert.equal(location.searchParams.get("auth_error"), "exchange_error");
  }

  assert.equal(exchangeCalls, 0);
});

test("accepts exact Next direct-loopback forwarding and rejects incomplete or multi-value headers", async () => {
  const nextForwardedHeaders = {
    Host: AUTH_CALLBACK_APP_HOST,
    "x-forwarded-host": AUTH_CALLBACK_APP_HOST,
    "x-forwarded-port": "3000",
    "x-forwarded-proto": "http",
    "x-forwarded-for": "127.0.0.1",
  };
  let exchangeCalls = 0;
  const providerError = await handleAuthCallback(
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?error=access_denied`, {
      headers: nextForwardedHeaders,
    }),
    async () => {
      exchangeCalls += 1;
      return { error: null };
    },
  );
  const providerLocation = new URL(providerError.headers.get("Location") ?? "");

  assert.equal(providerError.status, 303);
  assert.equal(providerLocation.searchParams.get("auth_error"), "provider_error");
  assert.equal(exchangeCalls, 0);

  for (const forwardedFor of ["::1", "::ffff:127.0.0.1"]) {
    const response = await handleAuthCallback(
      new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?error=access_denied`, {
        headers: { ...nextForwardedHeaders, "x-forwarded-for": forwardedFor },
      }),
      async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    );
    assert.equal(new URL(response.headers.get("Location") ?? "").searchParams.get("auth_error"), "provider_error");
  }

  const rejectedHeaders = [
    { ...nextForwardedHeaders, "x-forwarded-port": undefined },
    { ...nextForwardedHeaders, "x-forwarded-for": "127.0.0.1, 127.0.0.1" },
    { ...nextForwardedHeaders, "x-forwarded-proto": "https" },
  ];
  for (const headerValues of rejectedHeaders) {
    const headers = new Headers();
    for (const [name, value] of Object.entries(headerValues)) {
      if (value !== undefined) {
        headers.set(name, value);
      }
    }
    const response = await handleAuthCallback(
      new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
        headers,
      }),
      async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    );
    const location = new URL(response.headers.get("Location") ?? "");
    assert.equal(location.searchParams.get("auth_error"), "exchange_error");
  }

  assert.equal(exchangeCalls, 0);
});

test("passes only auth-js-compatible callback flow ids to the exchange", async () => {
  assert.equal(isValidPkceFlowId("a".repeat(8)), true);
  assert.equal(isValidPkceFlowId("a".repeat(64)), true);
  assert.equal(isValidPkceFlowId("a".repeat(7)), false);
  assert.equal(isValidPkceFlowId("a".repeat(65)), false);
  assert.equal(isValidPkceFlowId("flow.id"), false);

  const validFlowId = "flow_id-1";
  let receivedFlowId: string | undefined;
  const success = await handleAuthCallback(
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code&sb_flow_id=${validFlowId}`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    async (_code, flowId) => {
      receivedFlowId = flowId;
      return { error: null };
    },
  );
  assert.equal(success.status, 303);
  assert.equal(new URL(success.headers.get("Location") ?? "").pathname, "/");
  assert.equal(receivedFlowId, validFlowId);

  for (const invalidFlowId of ["short", "flow.id1", "a".repeat(65)]) {
    let exchangeCalls = 0;
    const response = await handleAuthCallback(
      new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code&sb_flow_id=${encodeURIComponent(invalidFlowId)}`, {
        headers: { Host: AUTH_CALLBACK_APP_HOST },
      }),
      async () => {
        exchangeCalls += 1;
        return { error: null };
      },
    );
    assert.equal(new URL(response.headers.get("Location") ?? "").searchParams.get("auth_error"), "exchange_error");
    assert.equal(exchangeCalls, 0);
  }

  let duplicateCalls = 0;
  const duplicate = await handleAuthCallback(
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code&sb_flow_id=${validFlowId}&sb_flow_id=${validFlowId}`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    async () => {
      duplicateCalls += 1;
      return { error: null };
    },
  );
  assert.equal(new URL(duplicate.headers.get("Location") ?? "").searchParams.get("auth_error"), "exchange_error");
  assert.equal(duplicateCalls, 0);
});

test("uses the fixed login origin for an unsafe callback destination", async () => {
  let exchangeCalls = 0;
  const response = await handleAuthCallback(
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code&next=https%3A%2F%2Foutside.invalid%2Fprivate`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    async () => {
      exchangeCalls += 1;
      return { error: null };
    },
  );
  const location = new URL(response.headers.get("Location") ?? "");

  assert.equal(response.status, 303);
  assert.equal(location.origin, AUTH_CALLBACK_APP_ORIGIN);
  assert.equal(location.pathname, "/account/login");
  assert.equal(location.searchParams.get("auth_error"), "exchange_error");
  assert.equal(location.toString().includes("outside.invalid"), false);
  assert.equal(exchangeCalls, 0);
});

test("ephemeral callback cookies follow auth-js single-flow and multi-flow names", async () => {
  const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];
  const flowId = "flow_id-1";
  const flowSlot = getRebuyPkceFlowSlotCookieName(flowId);
  const otherFlowSlot = getRebuyPkceFlowSlotCookieName("otherflow");
  const deletionOptions = {
    maxAge: 0,
    path: "/",
    sameSite: "lax",
    secure: false,
  } satisfies CookieOptions;
  const cookieStore = {
    getAll: () => [
      { name: REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME, value: "verifier" },
      { name: flowSlot, value: "flow-verifier" },
      { name: REBUY_PKCE_FLOW_INDEX_COOKIE_NAME, value: "[\"flow_id-1\"]" },
      { name: otherFlowSlot, value: "other-verifier" },
      { name: `${flowSlot}.0`, value: "chunked-verifier" },
      { name: "rebuy-g2-a1-e2a-auth-token", value: "provider-token-sentinel" },
      { name: "rebuy-g2-a1-e2a-auth-token.0", value: "provider-token-sentinel.0" },
    ],
    set: (name: string, value: string, options: CookieOptions) => {
      writes.push({ name, value, options });
    },
  };
  const methods = createEphemeralExchangeCookieMethods(cookieStore, flowId);
  const setAll = methods.setAll;

  assert.ok(setAll);
  assert.deepEqual(methods.getAll(), [
    { name: REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME, value: "verifier" },
    { name: flowSlot, value: "flow-verifier" },
    { name: REBUY_PKCE_FLOW_INDEX_COOKIE_NAME, value: "[\"flow_id-1\"]" },
  ]);

  await setAll(
    [
      {
        name: "rebuy-g2-a1-e2a-auth-token",
        value: "provider-token-sentinel",
        options: { ...deletionOptions, maxAge: 3600 },
      },
      {
        name: "rebuy-g2-a1-e2a-auth-token.0",
        value: "provider-token-sentinel.0",
        options: { ...deletionOptions, maxAge: 3600 },
      },
      {
        name: REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME,
        value: "",
        options: deletionOptions,
      },
      {
        name: flowSlot,
        value: "",
        options: { ...deletionOptions, secure: true },
      },
      { name: flowSlot, value: "", options: deletionOptions },
      { name: REBUY_PKCE_FLOW_INDEX_COOKIE_NAME, value: "", options: deletionOptions },
      {
        name: `${flowSlot}.0`,
        value: "",
        options: deletionOptions,
      },
    ],
    {},
  );

  assert.deepEqual(writes, [
    {
      name: REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME,
      value: "",
      options: deletionOptions,
    },
    { name: flowSlot, value: "", options: deletionOptions },
    { name: REBUY_PKCE_FLOW_INDEX_COOKIE_NAME, value: "", options: deletionOptions },
  ]);

  const legacyMethods = createEphemeralExchangeCookieMethods(cookieStore);
  assert.deepEqual(legacyMethods.getAll(), [
    { name: REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME, value: "verifier" },
  ]);
  assert.throws(
    () => createEphemeralExchangeCookieMethods(cookieStore, "short"),
    /Invalid callback flow identifier/,
  );
  assert.throws(
    () => getRebuyPkceFlowSlotCookieName("flow.id1"),
    /Invalid callback flow identifier/,
  );
});

test("requires a complete persisted session and never treats partial output as success", async () => {
  const persisted: Array<Record<string, unknown>> = [];
  const session = {
    access_token: "access-token",
    refresh_token: "refresh-token",
  };
  const success = await exchangeAndPersistSession(
    async () => ({
      data: {
        session: {
          ...session,
          provider_token: "provider-token-sentinel",
          provider_refresh_token: "provider-refresh-token-sentinel",
        },
      },
      error: null,
    }),
    async (tokens) => {
      persisted.push(tokens);
      return { data: { session }, error: null };
    },
  );

  assert.deepEqual(success, { kind: "success" });
  assert.deepEqual(persisted, [session]);
  assert.deepEqual(Object.keys(persisted[0] ?? {}).sort(), [
    "access_token",
    "refresh_token",
  ]);
  assert.equal(JSON.stringify(persisted).includes("provider-token-sentinel"), false);

  const missingTokens = await exchangeAndPersistSession(
    async () => ({
      data: { session: { provider_token: "provider-token-sentinel" } },
      error: null,
    }),
    async () => ({ data: { session }, error: null }),
  );
  const replayedExchange = await exchangeAndPersistSession(
    async () => ({ error: "replay" }),
    async () => ({ data: { session }, error: null }),
  );
  const nullPersistence = await exchangeAndPersistSession(
    async () => ({ data: { session }, error: null }),
    async () => ({ data: { session: null }, error: null }),
  );
  const partialPersistence = await exchangeAndPersistSession(
    async () => ({ data: { session }, error: null }),
    async () => ({ data: { session: { access_token: "access-token" } }, error: null }),
  );
  const persistenceFailure = await exchangeAndPersistSession(
    async () => ({ data: { session }, error: null }),
    async () => ({ data: { session }, error: "provider-persistence-error" }),
  );

  assert.deepEqual(missingTokens, { kind: "error", code: "missing_tokens" });
  assert.deepEqual(replayedExchange, { kind: "error", code: "exchange_failed" });
  assert.deepEqual(nullPersistence, { kind: "error", code: "persistence_failed" });
  assert.deepEqual(partialPersistence, { kind: "error", code: "persistence_failed" });
  assert.deepEqual(persistenceFailure, {
    kind: "error",
    code: "persistence_failed",
  });
  assert.equal(JSON.stringify([
    missingTokens,
    replayedExchange,
    nullPersistence,
    partialPersistence,
    persistenceFailure,
  ]).includes("provider"), false);
});

function makeTestJwt(exp: number) {
  return [
    encodeJwtPart({ alg: "HS256", typ: "JWT" }),
    encodeJwtPart({
      aud: "authenticated",
      exp,
      role: "authenticated",
      sub: "00000000-0000-0000-0000-000000000001",
    }),
    "fixture",
  ].join(".");
}

function makeRuntimeUser() {
  return {
    id: "00000000-0000-0000-0000-000000000001",
    aud: "authenticated",
    role: "authenticated",
    email: "runtime@rebuy.test",
    app_metadata: { provider: "email", providers: ["email"] },
    user_metadata: {},
    identities: [],
    created_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-01T00:00:00.000Z",
  };

}

test("real SSR setSession wiring writes only strict session cookies and no cookie on refresh failure", async () => {
  const createClientWithFetch = (fetch: typeof globalThis.fetch) => {
    const writes: Array<{ name: string; value: string; options: CookieOptions }> = [];
    const store = {
      getAll: () => [],
      set: (name: string, value: string, options: CookieOptions) => {
        writes.push({ name, value, options });
      },
    };
    const client = createServerClient(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture", {
      cookieOptions: REBUY_AUTH_COOKIE_OPTIONS,
      cookies: createServerCookieMethods(store, "strict"),
      global: { fetch },
    });
    return { client, writes };
  };

  const successRuntime = createClientWithFetch(async (input) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url);
    if (url.pathname.endsWith("/user")) {
      return new Response(JSON.stringify(makeRuntimeUser()), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(null, { status: 404 });
  });
  const accessToken = makeTestJwt(Math.floor(Date.now() / 1000) + 3600);
  let persistenceCalls = 0;
  const success = await exchangeAndPersistSession(
    async () => ({
      data: {
        session: {
          access_token: accessToken,
          refresh_token: "runtime-refresh-token",
          provider_token: "provider-token-sentinel",
          provider_refresh_token: "provider-refresh-token-sentinel",
        },
      },
      error: null,
    }),
    async (tokens) => {
      persistenceCalls += 1;
      const result = await successRuntime.client.auth.setSession(tokens);
      assert.equal(result.error, null);
      assert.ok(result.data.session);
      assert.equal(typeof result.data.session.access_token, "string");
      assert.equal(typeof result.data.session.refresh_token, "string");
      return result;
    },
  );

  assert.equal(persistenceCalls, 1);
  assert.deepEqual(success, { kind: "success" });
  assert.ok(successRuntime.writes.length > 0);
  assert.equal(successRuntime.writes.some(({ name }) =>
    name !== REBUY_AUTH_COOKIE_NAME && !name.startsWith(`${REBUY_AUTH_COOKIE_NAME}.`),
  ), false);
  assert.equal(successRuntime.writes.some(({ value }) =>
    value.includes("provider-token-sentinel") || value.includes("provider-refresh-token-sentinel"),
  ), false);

  const failureRuntime = createClientWithFetch(async (input) => {
    const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url);
    if (url.pathname.endsWith("/token")) {
      return new Response(JSON.stringify({ error: "invalid_grant" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }
    return new Response(null, { status: 404 });
  });
  const expiredToken = makeTestJwt(Math.floor(Date.now() / 1000) - 60);
  const failed = await exchangeAndPersistSession(
    async () => ({
      data: {
        session: {
          access_token: expiredToken,
          refresh_token: "runtime-refresh-token",
          provider_token: "provider-token-sentinel",
        },
      },
      error: null,
    }),
    (tokens) => failureRuntime.client.auth.setSession(tokens),
  );

  assert.deepEqual(failed, { kind: "error", code: "persistence_failed" });
  assert.deepEqual(failureRuntime.writes, []);
});

test("persists only access and refresh tokens and maps callback failures finitely", async () => {
  const persisted: Array<Record<string, unknown>> = [];
  const success = await exchangeAndPersistSession(
    async () => ({
      data: {
        session: {
          access_token: "access-token",
          refresh_token: "refresh-token",
          provider_token: "provider-token-sentinel",
          provider_refresh_token: "provider-refresh-token-sentinel",
        },
      },
      error: null,
    }),
    async (tokens) => {
      persisted.push(tokens);
      return { data: { session: tokens }, error: null };
    },
  );

  assert.deepEqual(success, { kind: "success" });
  assert.deepEqual(persisted, [
    { access_token: "access-token", refresh_token: "refresh-token" },
  ]);
  assert.deepEqual(Object.keys(persisted[0] ?? {}).sort(), [
    "access_token",
    "refresh_token",
  ]);
  assert.equal(JSON.stringify(persisted).includes("provider-token-sentinel"), false);
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
  return new Request(`${EMAIL_OTP_APP_ORIGIN}/api/auth/email-otp`, {
    method: "POST",
    headers: {
      Origin: EMAIL_OTP_APP_ORIGIN,
      Host: EMAIL_OTP_APP_HOST,
      "Content-Type": "application/json",
      ...headers,
    },
    body: JSON.stringify(value),
  });
}

async function responseJson(response: Response) {
  return (await response.json()) as Record<string, unknown>;
}

async function assertAuthUnavailable(response: Response) {
  assert.equal(response.status, 503);
  const body = await responseJson(response);
  assert.deepEqual(body, {
    status: "error",
    code: "auth_unavailable",
  });
  assert.match(response.headers.get("Content-Type") ?? "", /^application\/json/);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(response.headers.get("Pragma"), "no-cache");
  assert.equal(response.headers.get("Referrer-Policy"), "no-referrer");
  assert.equal(response.headers.get("Location"), null);
  assert.equal(response.headers.get("Set-Cookie"), null);
  assert.equal(JSON.stringify(body).includes("localhost"), false);
}

test("blocks production-like requests before adapter, cookie, exchange, or body access", async () => {
  const previewOrigin = "https://preview.rebuy.test";
  const previewHost = "preview.rebuy.test";
  let configReads = 0;
  let emailAdapterCalls = 0;
  let emailCookieFactoryCalls = 0;
  let sessionAdapterCalls = 0;
  let sessionCookieFactoryCalls = 0;
  let callbackExchangeCalls = 0;
  let callbackCookieFactoryCalls = 0;
  let logoutAdapterCalls = 0;
  let pullCount = 0;
  const readValidatedConfig = () => {
    configReads += 1;
    return validateSupabaseConfig(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture");
  };
  const readMode = (request: Request) =>
    resolveAuthRuntimeMode(request, readValidatedConfig);
  const postEmailOtp = createEmailOtpPostHandler(readMode, async () => {
    emailAdapterCalls += 1;
    emailCookieFactoryCalls += 1;
    return makeAdapter();
  });
  const getSession = createSessionGetHandler(readMode, async () => {
    sessionAdapterCalls += 1;
    sessionCookieFactoryCalls += 1;
    return { data: { claims: { sub: "must-not-be-read" } } };
  });
  const getAuthCallback = createAuthCallbackGetHandler(readMode, async () => {
    callbackExchangeCalls += 1;
    callbackCookieFactoryCalls += 1;
    return { error: null };
  });
  const postLogout = createLogoutPostHandler(readMode, async () => {
    logoutAdapterCalls += 1;
    return { signOut: async () => ({ error: null }) };
  });
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      pullCount += 1;
      controller.enqueue(new Uint8Array([123]));
      controller.close();
    },
  }, { highWaterMark: 0 });
  const emailRequest = new Request(`${previewOrigin}/api/auth/email-otp`, {
    method: "POST",
    headers: {
      Host: previewHost,
      Origin: previewOrigin,
      "Content-Type": "application/json",
    },
    body,
    duplex: "half",
  } as RequestInit);

  const emailResponse = await postEmailOtp(emailRequest);
  const sessionResponse = await getSession(
    new Request(`${previewOrigin}/api/auth/session`, {
      headers: { Host: previewHost },
    }),
  );
  const callbackResponse = await getAuthCallback(
    new Request(`${previewOrigin}/auth/callback?code=must-not-be-exchanged`, {
      headers: { Host: previewHost },
    }),
  );
  const logoutResponse = await postLogout(
    new Request(`${previewOrigin}/api/auth/logout`, {
      method: "POST",
      headers: { Host: previewHost, Origin: previewOrigin },
    }),
  );

  await assertAuthUnavailable(emailResponse);
  await assertAuthUnavailable(sessionResponse);
  await assertAuthUnavailable(callbackResponse);
  await assertAuthUnavailable(logoutResponse);
  assert.equal(configReads, 4);
  assert.equal(emailAdapterCalls, 0);
  assert.equal(emailCookieFactoryCalls, 0);
  assert.equal(sessionAdapterCalls, 0);
  assert.equal(sessionCookieFactoryCalls, 0);
  assert.equal(callbackExchangeCalls, 0);
  assert.equal(callbackCookieFactoryCalls, 0);
  assert.equal(logoutAdapterCalls, 0);
  assert.equal(emailRequest.bodyUsed, false);
  assert.equal(pullCount, 0);
});

test("delegates local-auth mode to the existing auth handlers", async () => {
  let emailAdapterCalls = 0;
  const emailResponse = await handleEmailOtpRequestForMode(
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }),
    "local-auth",
    async () => {
      emailAdapterCalls += 1;
      return makeAdapter();
    },
  );
  assert.equal(emailResponse.status, 200);
  assert.deepEqual(await responseJson(emailResponse), {
    status: "otp_sent",
  });
  assert.equal(emailAdapterCalls, 1);

  const authenticatedResponse = await handleSessionRequest("local-auth", async () => ({
    data: { claims: { sub: "local-user" } },
  }));
  const anonymousResponse = await handleSessionRequest("local-auth", async () => ({
    data: { claims: null },
    error: null,
  }));
  const errorResponse = await handleSessionRequest("local-auth", async () => ({
    data: null,
    error: new Error("local session error"),
  }));
  assert.equal(authenticatedResponse.status, 200);
  assert.deepEqual(await responseJson(authenticatedResponse), {
    status: "authenticated",
  });
  assert.equal(anonymousResponse.status, 401);
  assert.deepEqual(await responseJson(anonymousResponse), {
    status: "anonymous",
  });
  assert.equal(errorResponse.status, 500);
  assert.deepEqual(await responseJson(errorResponse), {
    status: "error",
    code: "session_error",
  });

  let exchangedCode = "";
  const callbackResponse = await handleAuthCallbackForMode(
    new Request(`${AUTH_CALLBACK_APP_ORIGIN}${AUTH_CALLBACK_PATH}?code=opaque-code`, {
      headers: { Host: AUTH_CALLBACK_APP_HOST },
    }),
    "local-auth",
    async (code) => {
      exchangedCode = code;
      return { error: null };
    },
  );
  assert.equal(callbackResponse.status, 303);
  assert.equal(new URL(callbackResponse.headers.get("Location") ?? "").pathname, "/");
  assert.equal(exchangedCode, "opaque-code");

  let logoutCalls = 0;
  const logoutResponse = await handleLogoutRequestForMode(
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: { Origin: LOGOUT_APP_ORIGIN, Host: LOGOUT_APP_HOST },
    }),
    "local-auth",
    async () => ({
      signOut: async () => {
        logoutCalls += 1;
        return { error: null };
      },
    }),
  );
  assert.equal(logoutResponse.status, 200);
  assert.equal(logoutCalls, 1);
});

test("reports both supported runtime modes through the app health contract", async () => {
  for (const mode of AUTH_RUNTIME_MODES) {
    const response = createAppHealthResponse(mode);
    assert.equal(response.status, 200);
    assert.deepEqual(await responseJson(response), {
      status: "healthy",
      mode,
    });
    assert.equal(response.headers.get("Cache-Control"), "no-store");
  }

  const readMode = (request: Request) =>
    resolveAuthRuntimeMode(request, () =>
      validateSupabaseConfig(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture"),
    );
  const getAppHealth = createAppHealthGetHandler(readMode);
  const canonicalResponse = await getAppHealth(
    new Request(`${LOCAL_APP_ORIGIN}/api/health/app`, {
      headers: { Host: LOCAL_APP_HOST },
    }),
  );
  const productionResponse = await getAppHealth(
    new Request("https://preview.rebuy.test/api/health/app", {
      headers: { Host: "preview.rebuy.test" },
    }),
  );
  assert.deepEqual(await responseJson(canonicalResponse), {
    status: "healthy",
    mode: "local-auth",
  });
  assert.deepEqual(await responseJson(productionResponse), {
    status: "healthy",
    mode: "ui-only",
  });
});

test("keeps the ui-only login render boundary and internal provider links explicit", () => {
  const source = readFileSync(
    resolve(process.cwd(), "app/account/login/LoginPrototype.tsx"),
    "utf8",
  );
  const pageSource = readFileSync(
    resolve(process.cwd(), "app/account/login/page.tsx"),
    "utf8",
  );
  const accountPageSource = readFileSync(
    resolve(process.cwd(), "app/account/page.tsx"),
    "utf8",
  );
  const accountClientSource = readFileSync(
    resolve(process.cwd(), "app/account/AccountClient.tsx"),
    "utf8",
  );
  const uiOnlyBranch = source.match(
    /\{mode === "ui-only" \? \(([\s\S]*?)\) : step === "email" \?/,
  )?.[1];

  assert.ok(uiOnlyBranch);
  assert.match(uiOnlyBranch, /账号登录暂未开放/);
  assert.match(uiOnlyBranch, /当前为界面预览/);
  assert.doesNotMatch(uiOnlyBranch, /<form/);
  assert.match(source, /mode === "ui-only" \|\| busyAction/);
  assert.match(source, /href="\/account\/provider\/google"/);
  assert.match(source, /href="\/account\/provider\/apple"/);
  assert.match(source, /mode === "local-auth"[\s\S]*styles\.intentTabs/);
  assert.match(pageSource, /headers\(\)/);
  assert.match(pageSource, /getAuthRuntimeModeForHost/);
  assert.match(pageSource, /mode=\{mode\}/);
  assert.match(pageSource, /nextPath=\{nextPath\}/);
  assert.match(accountPageSource, /getAuthRuntimeModeForHost/);
  assert.match(accountPageSource, /mode === "ui-only"/);
  assert.match(accountPageSource, /<AccountClient mode="ui-only"/);
  assert.match(accountPageSource, /<AccountClient mode="authenticated"/);
  assert.ok(
    accountPageSource.indexOf('mode === "ui-only"') <
      accountPageSource.indexOf("const session = await resolveSessionStatus"),
  );
  assert.match(accountClientSource, /const authenticated = mode === "authenticated"/);
});

test("wires actual routes through request-aware composition handlers", () => {
  const routeSources = [
    [
      "app/api/auth/email-otp/route.ts",
      "createEmailOtpPostHandler",
    ],
    ["app/api/auth/session/route.ts", "createSessionGetHandler"],
    ["app/api/auth/logout/route.ts", "createLogoutPostHandler"],
    ["app/auth/callback/route.ts", "createAuthCallbackGetHandler"],
    ["app/api/health/app/route.ts", "createAppHealthGetHandler"],
  ] as const;

  for (const [relativePath, compositionName] of routeSources) {
    const source = readFileSync(resolve(process.cwd(), relativePath), "utf8");
    assert.match(source, new RegExp(compositionName));
    assert.match(source, /getAuthRuntimeMode\(request\)/);
  }

  assert.match(
    readFileSync(resolve(process.cwd(), "app/api/auth/session/route.ts"), "utf8"),
    /GET\(request: Request\)/,
  );
});

test("requires both the canonical local app request and valid local config", () => {
  assert.deepEqual(AUTH_RUNTIME_MODES, ["ui-only", "local-auth"]);
  const canonicalRequest = new Request(`${LOCAL_APP_ORIGIN}/account/login`, {
    headers: { Host: LOCAL_APP_HOST },
  });
  const productionRequest = new Request("https://preview.rebuy.test/account/login", {
    headers: { Host: "preview.rebuy.test" },
  });
  let configReads = 0;
  const validLocalConfig = () => {
    configReads += 1;
    return validateSupabaseConfig(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture");
  };

  assert.equal(isCanonicalLocalAppRequest(canonicalRequest), true);
  assert.equal(isCanonicalLocalAppRequest(productionRequest), false);
  assert.equal(
    resolveAuthRuntimeMode(canonicalRequest, validLocalConfig),
    "local-auth",
  );
  assert.equal(
    resolveAuthRuntimeMode(productionRequest, validLocalConfig),
    "ui-only",
  );
  assert.equal(configReads, 2);
  assert.equal(
    resolveAuthRuntimeMode(canonicalRequest, () =>
      validateSupabaseConfig("https://hosted.supabase.co/", "sb_publishable_test_fixture"),
    ),
    "ui-only",
  );
  assert.throws(
    () =>
      resolveAuthRuntimeMode(canonicalRequest, () => {
        throw new Error("unexpected config failure");
      }),
    /unexpected config failure/,
  );
  assert.throws(
    () => resolveAuthRuntimeMode(productionRequest, () => {
      throw new Error("unexpected production config failure");
    }),
    /unexpected production config failure/,
  );
});

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
    { action: "request", email: "person@example.invalid", intent: "login" },
    { action: "request", email: syntheticEmail },
    { action: "request", email: syntheticEmail, intent: "unknown" },
    { action: "request", email: syntheticEmail, intent: "login", extra: true },
    { action: "verify", email: syntheticEmail, intent: "login", token: "1".repeat(EMAIL_OTP_LENGTH - 1) },
    { action: "verify", email: syntheticEmail, intent: "login", token: validOtp, extra: true },
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

test("separates login from signup and preserves intent when resending", async () => {
  const signInCalls: Array<{ email: string; shouldCreateUser: boolean }> = [];
  const adapter = makeAdapter({
    signInWithOtp: async ({ email, options }) => {
      signInCalls.push({ email, shouldCreateUser: options.shouldCreateUser });
      return { error: null };
    },
  });

  const request = await runEmailOtp(
    { action: "request", email: `  E2A-CONTRACT@${SYNTHETIC_EMAIL_DOMAIN.toUpperCase()} `, intent: "login" },
    adapter,
  );
  const resend = await runEmailOtp(
    { action: "resend", email: syntheticEmail, intent: "signup" },
    adapter,
  );

  assert.deepEqual(request, { kind: "success", action: "request", status: "otp_sent" });
  assert.deepEqual(resend, { kind: "success", action: "resend", status: "otp_sent" });
  assert.deepEqual(signInCalls, [
    { email: syntheticEmail, shouldCreateUser: false },
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
    { action: "verify", email: syntheticEmail, intent: "login", token: validOtp },
    adapter,
  );
  const replayed = await runEmailOtp(
    { action: "verify", email: syntheticEmail, intent: "login", token: validOtp },
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
    { action: "request", email: syntheticEmail, intent: "login" },
    makeAdapter({
      signInWithOtp: async () => {
        throw new Error("provider-request-error-that-must-not-leak");
      },
    }),
  );
  const verifyFailure = await runEmailOtp(
    { action: "verify", email: syntheticEmail, intent: "login", token: validOtp },
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
        body: JSON.stringify({ action: "request", email: syntheticEmail, intent: "login" }),
      }),
      status: 403,
      code: "origin_not_allowed",
    },
    {
      request: makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { Origin: "http://outside.invalid" }),
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
      request: makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, {
        "Content-Length": String(EMAIL_OTP_MAX_BODY_BYTES + 1),
      }),
      status: 413,
      code: "body_too_large",
    },
    {
      request: makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { "Content-Length": "not-a-size" }),
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
      request: makeJsonRequest({ action: "request", email: "person@example.invalid", intent: "login" }),
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
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }),
    createAdapter,
  );
  const verifyResponse = await handleEmailOtpRequest(
    makeJsonRequest({ action: "verify", email: syntheticEmail, intent: "login", token: validOtp }),
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
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }),
    async () => makeAdapter({
      signInWithOtp: async () => ({ error: new Error("raw-provider-message") }),
    }),
  );
  const factoryFailure = await handleEmailOtpRequest(
    makeJsonRequest({ action: "verify", email: syntheticEmail, intent: "login", token: validOtp }),
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

test("accepts only the canonical local URL and anonymous public key forms", () => {
  assert.equal(isAllowedSupabasePublicKey("sb_publishable_test_fixture"), true);
  assert.equal(isAllowedSupabasePublicKey(legacyAnonFixture), true);
  assert.deepEqual(
    validateSupabaseConfig(LOCAL_SUPABASE_URL, "sb_publishable_test_fixture"),
    {
      url: LOCAL_SUPABASE_URL,
      publishableKey: "sb_publishable_test_fixture",
    },
  );
  assert.deepEqual(
    validateSupabaseConfig(LOCAL_SUPABASE_URL, legacyAnonFixture),
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
      () => validateSupabaseConfig(url, "sb_publishable_test_fixture"),
      /Local Supabase configuration is invalid/,
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
      () => validateSupabaseConfig(LOCAL_SUPABASE_URL, key),
      /Local Supabase configuration is invalid/,
      key,
    );
  }
});

test("keeps Supabase environment reads server-only and browser config explicit", () => {
  const source = (relativePath: string) =>
    readFileSync(resolve(process.cwd(), relativePath), "utf8");
  const configSource = source("lib/supabase/config.ts");
  const serverConfigSource = source("lib/supabase/server-config.ts");
  const browserClientSource = source("lib/supabase/client.ts");

  assert.doesNotMatch(configSource, /\bprocess\.env\b/);
  assert.doesNotMatch(configSource, /NEXT_PUBLIC_/);
  assert.match(serverConfigSource, /import ["']server-only["']/);
  assert.match(serverConfigSource, /process\.env\.SUPABASE_URL/);
  assert.match(serverConfigSource, /process\.env\.SUPABASE_PUBLISHABLE_KEY/);
  assert.doesNotMatch(serverConfigSource, /NEXT_PUBLIC_/);
  assert.doesNotMatch(browserClientSource, /\bprocess\.env\b/);
  assert.doesNotMatch(browserClientSource, /NEXT_PUBLIC_/);
  assert.match(browserClientSource, /createClient\(config: SupabasePublicConfig\)/);
});

test("protects the account page with verified claims and never getSession", () => {
  const accountPage = readFileSync(
    resolve(process.cwd(), "app/account/page.tsx"),
    "utf8",
  );
  const sessionRoute = readFileSync(
    resolve(process.cwd(), "app/api/auth/session/route.ts"),
    "utf8",
  );

  for (const source of [accountPage, sessionRoute]) {
    assert.match(source, /auth[.]getClaims\(\)/);
    assert.doesNotMatch(source, /auth[.]getSession\(\)/);
  }
  assert.match(accountPage, /redirect\("\/account\/login\?next=%2Faccount"\)/);
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

test("maps only explicit rate limits and keeps resend cooldown aligned to local config", async () => {
  assert.equal(EMAIL_OTP_RESEND_COOLDOWN_MS, 1000);
  assert.equal(isRateLimitedAuthError({ status: 429, message: "raw provider text" }), true);
  assert.equal(isRateLimitedAuthError({ code: "over_email_send_rate_limit" }), true);
  assert.equal(isRateLimitedAuthError({ error_code: "too_many_requests" }), true);
  assert.equal(isRateLimitedAuthError("For security purposes, you can only request this after 1 second."), true);
  assert.equal(isRateLimitedAuthError({ message: "rate is not a limit" }), false);
  assert.equal(isRateLimitedAuthError({ code: "rate-something-else" }), false);
  assert.equal(isRateLimitedAuthError("a provider mentioned rate in an unrelated message"), false);

  const outcome = await runEmailOtp(
    { action: "resend", email: syntheticEmail, intent: "login" },
    makeAdapter({
      signInWithOtp: async () => ({
        error: { status: 429, message: "raw provider text that must not leak" },
      }),
    }),
  );
  assert.deepEqual(outcome, { kind: "error", action: "resend", code: "rate_limited" });
  assert.equal(JSON.stringify(outcome).includes("raw provider text"), false);
});

test("returns HTTP 429 for finite rate-limited route outcomes", async () => {
  const response = await handleEmailOtpRequest(
    makeJsonRequest({ action: "resend", email: syntheticEmail, intent: "login" }),
    async () => makeAdapter({
      signInWithOtp: async () => ({ error: { code: "over_email_send_rate_limit" } }),
    }),
  );

  assert.equal(response.status, 429);
  assert.deepEqual(await responseJson(response), {
    status: "error",
    code: "rate_limited",
  });
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
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { Host: "localhost:3000" }),
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { Host: "127.0.0.1:3000.evil" }),
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { Origin: "http://localhost:3000" }),
    makeJsonRequest({ action: "request", email: syntheticEmail, intent: "login" }, { Origin: "http://127.0.0.1:3000/" }),
    new Request("http://localhost:3000/api/auth/email-otp", {
      method: "POST",
      headers: {
        Origin: EMAIL_OTP_APP_ORIGIN,
        Host: EMAIL_OTP_APP_HOST,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ action: "request", email: syntheticEmail, intent: "login" }),
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

test("signs out only the current session through an exact same-origin POST", async () => {
  const calls: Array<{ scope: "local" }> = [];
  const response = await handleLogoutRequest(
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: { Origin: LOGOUT_APP_ORIGIN, Host: LOGOUT_APP_HOST },
    }),
    async () => ({
      signOut: async (options) => {
        calls.push(options);
        return { error: null };
      },
    }),
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await responseJson(response), { status: "signed_out" });
  assert.deepEqual(calls, [{ scope: "local" }]);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(response.headers.get("Referrer-Policy"), "no-referrer");
  assert.equal(response.headers.get("X-Content-Type-Options"), "nosniff");
});

test("rejects forged logout requests and maps provider failures finitely", async () => {
  let factoryCalls = 0;
  for (const request of [
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: { Host: LOGOUT_APP_HOST },
    }),
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: {
        Origin: "http://outside.invalid",
        Host: LOGOUT_APP_HOST,
      },
    }),
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: {
        Origin: LOGOUT_APP_ORIGIN,
        Host: LOGOUT_APP_HOST,
        "Content-Type": "application/json",
      },
      body: "{}",
    }),
  ]) {
    const response = await handleLogoutRequest(request, async () => {
      factoryCalls += 1;
      return { signOut: async () => ({ error: null }) };
    });
    assert.equal(response.status === 403 || response.status === 400, true);
  }
  assert.equal(factoryCalls, 0);

  const rawError = "raw signout provider failure";
  const failed = await handleLogoutRequest(
    new Request(`${LOGOUT_APP_ORIGIN}/api/auth/logout`, {
      method: "POST",
      headers: { Origin: LOGOUT_APP_ORIGIN, Host: LOGOUT_APP_HOST },
    }),
    async () => ({ signOut: async () => ({ error: new Error(rawError) }) }),
  );
  const body = await responseJson(failed);
  assert.equal(failed.status, 500);
  assert.deepEqual(body, { status: "error", code: "signout_failed" });
  assert.equal(JSON.stringify(body).includes(rawError), false);
});
