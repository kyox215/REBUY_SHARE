import {
  SupabaseConfigError,
  type SupabasePublicConfig,
} from "../supabase/config";
import {
  AppOriginConfigError,
  getTrustedHostedAppOrigin,
  isCanonicalLocalAppRequest,
} from "./app-origin";

export const AUTH_RUNTIME_MODES = ["ui-only", "local-auth", "hosted-auth"] as const;
export type AuthRuntimeMode = (typeof AUTH_RUNTIME_MODES)[number];
export type AuthRuntimeModeReader = (request: Request) => AuthRuntimeMode;

export function isAuthRuntimeEnabled(mode: AuthRuntimeMode) {
  return mode !== "ui-only";
}

export function resolveAuthRuntimeMode(
  request: Request,
  readValidatedConfig: () => SupabasePublicConfig,
  readHostedAppOrigins: () => readonly string[] = () => [],
): AuthRuntimeMode {
  let config: SupabasePublicConfig;
  try {
    config = readValidatedConfig();
  } catch (error) {
    if (error instanceof SupabaseConfigError || error instanceof AppOriginConfigError) {
      return "ui-only";
    }

    throw error;
  }

  if (config.runtimeMode === "local-auth") {
    return isCanonicalLocalAppRequest(request) ? "local-auth" : "ui-only";
  }

  try {
    return getTrustedHostedAppOrigin(request, readHostedAppOrigins())
      ? "hosted-auth"
      : "ui-only";
  } catch (error) {
    if (error instanceof AppOriginConfigError) {
      return "ui-only";
    }
    throw error;
  }
}
