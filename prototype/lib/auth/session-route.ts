import { authUnavailableResponse, AUTH_UNAVAILABLE_HEADERS } from "./auth-unavailable";
import { resolveSessionStatus, type SessionClaimsResult } from "./session";
import type { AuthRuntimeMode } from "./runtime-mode-core";

export type SessionClaimsFactory = () => Promise<SessionClaimsResult>;

export async function handleSessionRequest(
  mode: AuthRuntimeMode,
  getClaims: SessionClaimsFactory,
) {
  if (mode === "ui-only") {
    return authUnavailableResponse();
  }

  const session = await resolveSessionStatus({ getClaims });

  if (session.status === "authenticated") {
    return Response.json(
      { status: "authenticated" },
      { status: 200, headers: AUTH_UNAVAILABLE_HEADERS },
    );
  }

  if (session.status === "anonymous") {
    return Response.json(
      { status: "anonymous" },
      { status: 401, headers: AUTH_UNAVAILABLE_HEADERS },
    );
  }

  return Response.json(
    { status: "error", code: "session_error" },
    { status: 500, headers: AUTH_UNAVAILABLE_HEADERS },
  );
}
