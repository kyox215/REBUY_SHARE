import "server-only";

import {
  validateSupabaseConfig,
  type SupabasePublicConfig,
} from "./config";

export function getSupabaseServerConfig(): SupabasePublicConfig {
  return validateSupabaseConfig(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_PUBLISHABLE_KEY,
  );
}
