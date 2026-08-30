"use client";

import { createBrowserClient } from "@supabase/ssr";

import {
  REBUY_AUTH_COOKIE_OPTIONS,
  validateSupabaseConfig,
  type SupabasePublicConfig,
} from "./config";

export function createClient(config: SupabasePublicConfig) {
  const { url, publishableKey } = validateSupabaseConfig(
    config.url,
    config.publishableKey,
  );

  return createBrowserClient(url, publishableKey, {
    cookieOptions: REBUY_AUTH_COOKIE_OPTIONS,
  });
}
