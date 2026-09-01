import { SupabaseConfigError } from "../supabase/config";
import { isCanonicalLocalAppRequest } from "./app-origin";

export const AUTH_RUNTIME_MODES = ["ui-only", "local-auth"] as const;
export type AuthRuntimeMode = (typeof AUTH_RUNTIME_MODES)[number];
export type AuthRuntimeModeReader = (request: Request) => AuthRuntimeMode;

export function resolveAuthRuntimeMode(
  request: Request,
  readValidatedConfig: () => unknown,
): AuthRuntimeMode {
  try {
    readValidatedConfig();
  } catch (error) {
    if (error instanceof SupabaseConfigError) {
      return "ui-only";
    }

    throw error;
  }

  return isCanonicalLocalAppRequest(request) ? "local-auth" : "ui-only";
}
