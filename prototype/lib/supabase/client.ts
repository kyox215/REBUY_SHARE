"use client";

import { createBrowserClient } from "@supabase/ssr";

import { getSupabaseConfig, REBUY_AUTH_COOKIE_OPTIONS } from "./config";

export function createClient() {
  const { url, publishableKey } = getSupabaseConfig();

  return createBrowserClient(url, publishableKey, {
    cookieOptions: REBUY_AUTH_COOKIE_OPTIONS,
  });
}
