import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { REBUY_AUTH_COOKIE_OPTIONS } from "./config";
import { createServerCookieMethods } from "./cookies";
import { getSupabaseServerConfig } from "./server-config";

export async function createClient() {
  return createConfiguredServerClient("readonly");
}

export async function createAuthRouteClient() {
  return createConfiguredServerClient("strict");
}

async function createConfiguredServerClient(mode: "readonly" | "strict") {
  const { url, publishableKey } = getSupabaseServerConfig();
  const cookieStore = await cookies();

  return createServerClient(url, publishableKey, {
    cookieOptions: REBUY_AUTH_COOKIE_OPTIONS,
    cookies: createServerCookieMethods(cookieStore, mode),
  });
}

// Protected pages and data must use supabase.auth.getClaims(), never getSession() for auth.
