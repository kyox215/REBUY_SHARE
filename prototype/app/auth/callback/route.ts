import { handleAuthCallback } from "@/lib/auth/callback-route";
import { createAuthRouteClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  return handleAuthCallback(request, async (code) => {
    const supabase = await createAuthRouteClient();
    return supabase.auth.exchangeCodeForSession(code);
  });
}
