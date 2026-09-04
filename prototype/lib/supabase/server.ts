import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { createEphemeralExchangeCookieMethods } from "../auth/callback-session";
import { getRebuyAuthCookieOptions } from "./config";
import { createServerCookieMethods } from "./cookies";
import { getSupabaseServerConfig } from "./server-config";

export async function createClient() {
  return createConfiguredServerClient("readonly");
}

export async function createAuthRouteClient() {
  return createConfiguredServerClient("strict");
}

export async function createAuthCallbackClients(flowId?: string) {
  const config = getSupabaseServerConfig();
  const { url, publishableKey } = config;
  const cookieStore = await cookies();
  const options = {
    cookieOptions: getRebuyAuthCookieOptions(config.runtimeMode),
  } as const;

  return {
    exchange: createServerClient(url, publishableKey, {
      ...options,
      cookies: createEphemeralExchangeCookieMethods(cookieStore, flowId),
    }),
    persistence: createServerClient(url, publishableKey, {
      ...options,
      cookies: createServerCookieMethods(cookieStore, "strict"),
    }),
  };
}

async function createConfiguredServerClient(mode: "readonly" | "strict") {
  const { url, publishableKey, runtimeMode } = getSupabaseServerConfig();
  const cookieStore = await cookies();

  return createServerClient(url, publishableKey, {
    cookieOptions: getRebuyAuthCookieOptions(runtimeMode),
    cookies: createServerCookieMethods(cookieStore, mode),
  });
}

// Protected pages and data must use supabase.auth.getClaims(), never getSession() for auth.
