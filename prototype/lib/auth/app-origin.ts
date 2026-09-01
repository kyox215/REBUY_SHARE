export const LOCAL_APP_ORIGIN = "http://127.0.0.1:3000";
export const LOCAL_APP_HOST = "127.0.0.1:3000";

export function isCanonicalLocalAppRequest(request: Request) {
  try {
    return (
      new URL(request.url).origin === LOCAL_APP_ORIGIN &&
      request.headers.get("host") === LOCAL_APP_HOST
    );
  } catch {
    return false;
  }
}
