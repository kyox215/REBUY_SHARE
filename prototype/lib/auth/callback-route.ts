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

function loginRedirect(code: AuthCallbackErrorCode) {
  const target = new URL("/account/login", AUTH_CALLBACK_APP_ORIGIN);
  target.searchParams.set("auth_error", code);
  target.hash = "";

  return redirectResponse(target);
}

function isTrustedCallbackRequest(request: Request, requestUrl: URL) {
  if (
    requestUrl.origin !== AUTH_CALLBACK_APP_ORIGIN ||
    requestUrl.pathname !== AUTH_CALLBACK_PATH ||
    requestUrl.username !== "" ||
    requestUrl.password !== "" ||
    requestUrl.hash !== "" ||
    request.headers.get("host") !== AUTH_CALLBACK_APP_HOST
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

  return (
    forwardedValues["x-forwarded-host"] === AUTH_CALLBACK_APP_HOST &&
    forwardedValues["x-forwarded-port"] === "3000" &&
    forwardedValues["x-forwarded-proto"] === "http" &&
    nextLoopbackAddresses.has(forwardedValues["x-forwarded-for"] ?? "")
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
) {
  let requestUrl: URL;
  try {
    requestUrl = new URL(request.url);
  } catch {
    return loginRedirect("exchange_error");
  }

  if (!isTrustedCallbackRequest(request, requestUrl)) {
    return loginRedirect("exchange_error");
  }

  const searchParams = requestUrl.searchParams;
  if (hasUnsafeNext(searchParams.get("next"))) {
    return loginRedirect("exchange_error");
  }

  const flowIds = searchParams.getAll("sb_flow_id");
  if (flowIds.length > 1 || (flowIds.length === 1 && !isValidPkceFlowId(flowIds[0]))) {
    return loginRedirect("exchange_error");
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
    return loginRedirect("exchange_error");
  }

  if (decision.kind === "error") {
    return loginRedirect(decision.code);
  }

  if (decision.kind !== "success" || typeof decision.next !== "string") {
    return loginRedirect("exchange_error");
  }

  try {
    if (!decision.next.startsWith("/") || decision.next.startsWith("//")) {
      return loginRedirect("exchange_error");
    }

    const target = new URL(decision.next, AUTH_CALLBACK_APP_ORIGIN);
    if (target.origin !== AUTH_CALLBACK_APP_ORIGIN) {
      return loginRedirect("exchange_error");
    }

    return redirectResponse(target);
  } catch {
    return loginRedirect("exchange_error");
  }
}

export async function handleAuthCallbackForMode(
  request: Request,
  mode: AuthRuntimeMode,
  exchange: AuthCodeExchange,
  decider: AuthCallbackDecider = decideAuthCallback,
) {
  if (mode === "ui-only") {
    return authUnavailableResponse();
  }

  return handleAuthCallback(request, exchange, decider);
}
