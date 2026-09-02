import { handleLogoutRequest } from "@/lib/auth/logout";
import { createAuthRouteClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  return handleLogoutRequest(request, async () => {
    const supabase = await createAuthRouteClient();
    return {
      signOut: (options: { scope: "local" }) => supabase.auth.signOut(options),
    };
  });
}
