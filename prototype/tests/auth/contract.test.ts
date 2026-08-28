import assert from "node:assert/strict";
import { test } from "node:test";

import {
  AUTH_CALLBACK_ERROR_MESSAGES,
  decideAuthCallback,
  isAuthCallbackErrorCode,
} from "../../lib/auth/callback";
import { normalizeSafeNext } from "../../lib/auth/redirect";

test("normalizes safe same-origin destinations", () => {
  const acceptedDestinations = [
    "/",
    "/catalog?query=usb-c#results",
    "/products/charger%20stand",
    "/products//related",
  ];

  for (const destination of acceptedDestinations) {
    assert.equal(normalizeSafeNext(destination), destination);
  }
});

test("rejects external, encoded, and control-character destinations", () => {
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
    "/%invalid",
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
