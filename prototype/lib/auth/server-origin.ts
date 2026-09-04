import "server-only";

import {
  LOCAL_APP_ORIGIN,
  getTrustedHostedAppOrigin,
  validateHostedAppOrigins,
} from "./app-origin";
import type { AuthRuntimeMode } from "./runtime-mode-core";

export function getConfiguredHostedAppOrigins() {
  return validateHostedAppOrigins(
    process.env.REBUY_APP_ORIGIN,
    process.env.VERCEL_ENV,
    process.env.VERCEL_URL,
  );
}

export function getPrimaryAppOrigin(mode: AuthRuntimeMode) {
  if (mode === "local-auth") {
    return LOCAL_APP_ORIGIN;
  }
  if (mode === "hosted-auth") {
    try {
      return getConfiguredHostedAppOrigins()[0] ?? null;
    } catch {
      return null;
    }
  }
  return null;
}

export function getTrustedAppOriginForRequest(
  request: Request,
  mode: AuthRuntimeMode,
) {
  if (mode === "local-auth") {
    try {
      const requestUrl = new URL(request.url);
      return requestUrl.origin === LOCAL_APP_ORIGIN &&
        request.headers.get("host") === requestUrl.host
        ? LOCAL_APP_ORIGIN
        : null;
    } catch {
      return null;
    }
  }

  if (mode !== "hosted-auth") {
    return null;
  }

  try {
    return getTrustedHostedAppOrigin(request, getConfiguredHostedAppOrigins());
  } catch {
    return null;
  }
}
