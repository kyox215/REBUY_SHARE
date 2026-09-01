export const AUTH_UNAVAILABLE_HEADERS = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
} as const;

export function authUnavailableResponse() {
  return Response.json(
    { status: "error", code: "auth_unavailable" },
    { status: 503, headers: AUTH_UNAVAILABLE_HEADERS },
  );
}
