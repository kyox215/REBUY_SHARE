import { handleAuthCallback } from "@/lib/auth/callback-route";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  return handleAuthCallback(request, async (code) => {
    const supabase = await createClient();
    return supabase.auth.exchangeCodeForSession(code);
  });
}
