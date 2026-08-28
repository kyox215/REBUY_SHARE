import assert from "node:assert/strict";
import { test } from "node:test";

import {
  AUTH_CALLBACK_CODE_MAX_LENGTH,
  AUTH_CALLBACK_ERROR_MESSAGES,
  decideAuthCallback,
  isAuthCallbackErrorCode,
} from "../../lib/auth/callback";
import { handleAuthCallback } from "../../lib/auth/callback-route";
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
