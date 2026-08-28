import {
  decideAuthCallback,
  type AuthCallbackDecision,
  type AuthCallbackErrorCode,
  type AuthCallbackInput,
  type AuthCodeExchange,
} from "./callback";

const redirectHeaders = {
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
};

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

function loginRedirect(requestUrl: URL, code: AuthCallbackErrorCode) {
  const target = new URL("/account/login", requestUrl);
  target.searchParams.set("auth_error", code);
  target.hash = "";

  return redirectResponse(target);
}

/**
 * Apply the callback decision policy to a request without binding it to a
 * provider client. The production route supplies the existing SSR exchange;
 * tests can inject a deterministic decider and verify the final origin check.
 */
export async function handleAuthCallback(
  request: Request,
  exchange: AuthCodeExchange,
  decider: AuthCallbackDecider = decideAuthCallback,
) {
  const requestUrl = new URL(request.url);
  const searchParams = requestUrl.searchParams;

  let decision: AuthCallbackDecision;
  try {
    decision = await decider({
      code: searchParams.get("code"),
      error: searchParams.get("error"),
      errorDescription: searchParams.get("error_description"),
      next: searchParams.get("next"),
      exchange,
    });
  } catch {
    return loginRedirect(requestUrl, "exchange_error");
  }

  if (decision.kind === "error") {
    return loginRedirect(requestUrl, decision.code);
  }

  if (decision.kind !== "success" || typeof decision.next !== "string") {
    return loginRedirect(requestUrl, "exchange_error");
  }

  try {
    const target = new URL(decision.next, requestUrl);
    if (target.origin !== requestUrl.origin) {
      return loginRedirect(requestUrl, "exchange_error");
    }

    return redirectResponse(target);
  } catch {
    return loginRedirect(requestUrl, "exchange_error");
  }
}
