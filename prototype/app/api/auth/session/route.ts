import { createSessionGetHandler } from "@/lib/auth/route-composition";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthRouteClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const getSession = createSessionGetHandler(
  (request) => getAuthRuntimeMode(request),
  async () => {
    const supabase = await createAuthRouteClient();
    return supabase.auth.getClaims();
  },
);

export function GET(request: Request) {
  return getSession(request);
}
