import "server-only";

import { LOCAL_APP_ORIGIN } from "./app-origin";
import { getSupabaseServerConfig } from "../supabase/server-config";
import {
  resolveAuthRuntimeMode,
  type AuthRuntimeMode,
} from "./runtime-mode-core";
import { getConfiguredHostedAppOrigins } from "./server-origin";

export type { AuthRuntimeMode } from "./runtime-mode-core";

export function getAuthRuntimeMode(request: Request): AuthRuntimeMode {
  return resolveAuthRuntimeMode(
    request,
    getSupabaseServerConfig,
    getConfiguredHostedAppOrigins,
  );
}

export function getAuthRuntimeModeForHost(host: string | null): AuthRuntimeMode {
  try {
    const requestOrigin = host === "127.0.0.1:3000"
      ? LOCAL_APP_ORIGIN
      : `https://${host ?? "invalid.invalid"}`;
    return getAuthRuntimeMode(
      new Request(`${requestOrigin}/account/login`, {
        headers: { Host: host ?? "" },
      }),
    );
  } catch {
    return "ui-only";
  }
}
