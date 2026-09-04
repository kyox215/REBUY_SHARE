import { authUnavailableResponse } from "./auth-unavailable";
import type { AuthRuntimeMode } from "./runtime-mode-core";

export const LOGOUT_APP_ORIGIN = "http://127.0.0.1:3000";
export const LOGOUT_APP_HOST = "127.0.0.1:3000";

const noStoreHeaders = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

export type LogoutAuthAdapter = {
  signOut: (options: { scope: "local" }) => Promise<
    { error?: unknown | null } | null | undefined
  >;
};

export type LogoutAuthAdapterFactory = () =>
  | LogoutAuthAdapter
  | Promise<LogoutAuthAdapter>;

function isSameOrigin(request: Request, appOrigin: string) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");
  if (!origin || !host) return false;

  try {
    return (
      new URL(request.url).origin === appOrigin &&
      origin === appOrigin &&
      host === new URL(appOrigin).host
    );
  } catch {
    return false;
  }
}

function jsonResponse(body: Record<string, string>, status: number) {
  return Response.json(body, { status, headers: noStoreHeaders });
}

export async function handleLogoutRequest(
  request: Request,
  createAuthAdapter: LogoutAuthAdapterFactory,
  appOrigin = LOGOUT_APP_ORIGIN,
) {
  if (!isSameOrigin(request, appOrigin)) {
    return jsonResponse({ status: "error", code: "origin_not_allowed" }, 403);
  }

  const contentLength = request.headers.get("content-length");
  if (
    request.headers.has("content-type") ||
    (contentLength !== null && contentLength !== "0")
  ) {
    return jsonResponse({ status: "error", code: "invalid_request" }, 400);
  }

  try {
    const adapter = await createAuthAdapter();
    const result = await adapter.signOut({ scope: "local" });
    if (!result || result.error) {
      return jsonResponse({ status: "error", code: "signout_failed" }, 500);
    }

    return jsonResponse({ status: "signed_out" }, 200);
  } catch {
    return jsonResponse({ status: "error", code: "signout_failed" }, 500);
  }
}

export async function handleLogoutRequestForMode(
  request: Request,
  mode: AuthRuntimeMode,
  createAuthAdapter: LogoutAuthAdapterFactory,
  appOrigin?: string | null,
) {
  const resolvedOrigin = appOrigin ?? (mode === "local-auth" ? LOGOUT_APP_ORIGIN : null);
  if (mode === "ui-only" || !resolvedOrigin) {
    return authUnavailableResponse();
  }

  return handleLogoutRequest(request, createAuthAdapter, resolvedOrigin);
}
