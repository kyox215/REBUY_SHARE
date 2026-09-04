import {
  decideAuthCallback,
  type AuthCallbackDecision,
  type AuthCallbackErrorCode,
  type AuthCallbackInput,
  type AuthCodeExchange,
} from "./callback";
import { LOCAL_APP_HOST, LOCAL_APP_ORIGIN } from "./app-origin";
import { isValidPkceFlowId } from "./callback-session";
import { normalizeSafeNext } from "./redirect";
import { authUnavailableResponse } from "./auth-unavailable";
import type { AuthRuntimeMode } from "./runtime-mode-core";

const redirectHeaders = {
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
};

export const AUTH_CALLBACK_APP_ORIGIN = LOCAL_APP_ORIGIN;
export const AUTH_CALLBACK_APP_HOST = LOCAL_APP_HOST;
export const AUTH_CALLBACK_PATH = "/auth/callback";

const nextForwardedHeaderNames = new Set([
  "x-forwarded-for",
  "x-forwarded-host",
  "x-forwarded-port",
  "x-forwarded-proto",
]);

const rejectedForwardedHeaderNames = new Set([
  "forwarded",
  "x-real-ip",
]);

const nextLoopbackAddresses = new Set([
  "127.0.0.1",
  "::1",
  "::ffff:127.0.0.1",
]);

export type AuthCallbackDecider = (
  input: AuthCallbackInput,
) => Promise<AuthCallbackDecision>;

function redirectResponse(target: URL) {
  const headers = new Headers(redirectHeaders);
  headers.set("Location", target.toString());

  return new Response(null, {
    status: 303,
    headers,
  });
}

function loginRedirect(code: AuthCallbackErrorCode, appOrigin: string) {
  const target = new URL("/account/login", appOrigin);
  target.searchParams.set("auth_error", code);
  target.hash = "";

  return redirectResponse(target);
}

function isTrustedCallbackRequest(
  request: Request,
  requestUrl: URL,
  appOrigin: string,
) {
  const expectedUrl = new URL(appOrigin);
  if (
    requestUrl.origin !== expectedUrl.origin ||
    requestUrl.pathname !== AUTH_CALLBACK_PATH ||
    requestUrl.username !== "" ||
    requestUrl.password !== "" ||
    requestUrl.hash !== "" ||
    request.headers.get("host") !== expectedUrl.host
  ) {
    return false;
  }

  const forwardedValues: Record<string, string> = {};
  let hasForwardedHeader = false;
  let hasRejectedHeader = false;
  request.headers.forEach((value, headerName) => {
    if (
      rejectedForwardedHeaderNames.has(headerName) ||
      headerName.startsWith("x-original-")
    ) {
      hasRejectedHeader = true;
      return;
    }

    if (headerName.startsWith("x-forwarded-")) {
      hasForwardedHeader = true;
      if (!nextForwardedHeaderNames.has(headerName)) {
        hasRejectedHeader = true;
        return;
      }

      forwardedValues[headerName] = value;
    }
  });

  if (hasRejectedHeader || !hasForwardedHeader) {
    return !hasRejectedHeader;
  }

  if (
    forwardedValues["x-forwarded-host"] !== expectedUrl.host ||
    forwardedValues["x-forwarded-proto"] !== expectedUrl.protocol.slice(0, -1)
  ) {
    return false;
  }

  if (appOrigin === AUTH_CALLBACK_APP_ORIGIN) {
    return (
      forwardedValues["x-forwarded-port"] === "3000" &&
      nextLoopbackAddresses.has(forwardedValues["x-forwarded-for"] ?? "")
    );
  }

  const forwardedPort = forwardedValues["x-forwarded-port"];
  const forwardedFor = forwardedValues["x-forwarded-for"] ?? "";
  const forwardedAddresses = forwardedFor.split(",").map((value) => value.trim());
  return (
    (forwardedPort === undefined || forwardedPort === "443") &&
    forwardedFor.length > 0 &&
    forwardedFor.length <= 256 &&
    forwardedAddresses.every((value) => /^[0-9a-f:.]+$/i.test(value))
  );
}

function hasUnsafeNext(requestedNext: string | null) {
  return (
    requestedNext !== null &&
    requestedNext.length > 0 &&
    requestedNext !== "/" &&
    normalizeSafeNext(requestedNext) === "/"
  );
}

/**
 * Apply the callback decision policy to a fixed local callback request without
 * binding it to a provider client. The production route supplies the
 * two-stage exchange adapter; tests can inject a deterministic decider.
 */
export async function handleAuthCallback(
  request: Request,
  exchange: AuthCodeExchange,
  decider: AuthCallbackDecider = decideAuthCallback,
  appOrigin = AUTH_CALLBACK_APP_ORIGIN,
) {
  let requestUrl: URL;
  try {
    requestUrl = new URL(request.url);
  } catch {
    return loginRedirect("exchange_error", appOrigin);
  }

  if (!isTrustedCallbackRequest(request, requestUrl, appOrigin)) {
    return loginRedirect("exchange_error", appOrigin);
  }

  const searchParams = requestUrl.searchParams;
  if (hasUnsafeNext(searchParams.get("next"))) {
    return loginRedirect("exchange_error", appOrigin);
  }

  const flowIds = searchParams.getAll("sb_flow_id");
  if (flowIds.length > 1 || (flowIds.length === 1 && !isValidPkceFlowId(flowIds[0]))) {
    return loginRedirect("exchange_error", appOrigin);
  }
  const flowId = flowIds[0];

  let decision: AuthCallbackDecision;
  try {
    decision = await decider({
      code: searchParams.get("code"),
      error: searchParams.get("error"),
      errorDescription: searchParams.get("error_description"),
      next: searchParams.get("next"),
      flowId,
      exchange,
    });
  } catch {
    return loginRedirect("exchange_error", appOrigin);
  }

  if (decision.kind === "error") {
    return loginRedirect(decision.code, appOrigin);
  }

  if (decision.kind !== "success" || typeof decision.next !== "string") {
    return loginRedirect("exchange_error", appOrigin);
  }

  try {
    if (!decision.next.startsWith("/") || decision.next.startsWith("//")) {
      return loginRedirect("exchange_error", appOrigin);
    }

    const target = new URL(decision.next, appOrigin);
    if (target.origin !== appOrigin) {
      return loginRedirect("exchange_error", appOrigin);
    }

    return redirectResponse(target);
  } catch {
    return loginRedirect("exchange_error", appOrigin);
  }
}

export async function handleAuthCallbackForMode(
  request: Request,
  mode: AuthRuntimeMode,
  exchange: AuthCodeExchange,
  decider: AuthCallbackDecider = decideAuthCallback,
  appOrigin?: string | null,
) {
  const resolvedOrigin = appOrigin ?? (mode === "local-auth" ? AUTH_CALLBACK_APP_ORIGIN : null);
  if (mode === "ui-only" || !resolvedOrigin) {
    return authUnavailableResponse();
  }

  return handleAuthCallback(request, exchange, decider, resolvedOrigin);
}
