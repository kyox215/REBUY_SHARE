export const LOCAL_APP_ORIGIN = "http://127.0.0.1:3000";
export const LOCAL_APP_HOST = "127.0.0.1:3000";

const dnsHostnamePattern = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;

export class AppOriginConfigError extends Error {
  constructor() {
    super("Hosted application origin is invalid.");
    this.name = "AppOriginConfigError";
  }
}

export function normalizeHostedAppOrigin(value: unknown): string | null {
  if (typeof value !== "string" || value.length === 0 || value.length > 300) {
    return null;
  }

  try {
    const url = new URL(value);
    if (
      url.protocol !== "https:" ||
      url.username !== "" ||
      url.password !== "" ||
      url.port !== "" ||
      url.pathname !== "/" ||
      url.search !== "" ||
      url.hash !== "" ||
      !dnsHostnamePattern.test(url.hostname) ||
      url.hostname === "localhost" ||
      url.hostname.endsWith(".localhost") ||
      url.hostname.endsWith(".local")
    ) {
      return null;
    }

    return url.origin;
  } catch {
    return null;
  }
}

export function validateHostedAppOrigins(
  primaryOrigin: unknown,
  vercelEnvironment?: unknown,
  vercelUrl?: unknown,
) {
  const primary = normalizeHostedAppOrigin(primaryOrigin);
  if (!primary) {
    throw new AppOriginConfigError();
  }

  const origins = new Set([primary]);
  if (
    (vercelEnvironment === "preview" || vercelEnvironment === "production") &&
    typeof vercelUrl === "string" &&
    vercelUrl.length > 0
  ) {
    const deploymentOrigin = normalizeHostedAppOrigin(`https://${vercelUrl}`);
    if (!deploymentOrigin || !deploymentOrigin.endsWith(".vercel.app")) {
      throw new AppOriginConfigError();
    }
    origins.add(deploymentOrigin);
  }

  return [...origins];
}

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

export function getTrustedHostedAppOrigin(
  request: Request,
  allowedOrigins: readonly string[],
) {
  try {
    const requestUrl = new URL(request.url);
    return allowedOrigins.includes(requestUrl.origin) &&
      request.headers.get("host") === requestUrl.host
      ? requestUrl.origin
      : null;
  } catch {
    return null;
  }
}
