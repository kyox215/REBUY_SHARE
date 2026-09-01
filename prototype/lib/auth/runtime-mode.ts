import "server-only";

import { LOCAL_APP_ORIGIN } from "./app-origin";
import { getSupabaseServerConfig } from "../supabase/server-config";
import {
  resolveAuthRuntimeMode,
  type AuthRuntimeMode,
} from "./runtime-mode-core";

export type { AuthRuntimeMode } from "./runtime-mode-core";

export function getAuthRuntimeMode(request: Request): AuthRuntimeMode {
  return resolveAuthRuntimeMode(request, getSupabaseServerConfig);
}

export function getAuthRuntimeModeForHost(host: string | null): AuthRuntimeMode {
  return getAuthRuntimeMode(
    new Request(`${LOCAL_APP_ORIGIN}/account/login`, {
      headers: { Host: host ?? "" },
    }),
  );
}
