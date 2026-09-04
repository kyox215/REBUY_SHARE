import { createLogoutPostHandler } from "@/lib/auth/route-composition";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthRouteClient } from "@/lib/supabase/server";
import { getTrustedAppOriginForRequest } from "@/lib/auth/server-origin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const postLogout = createLogoutPostHandler(
  (request) => getAuthRuntimeMode(request),
  async () => {
    const supabase = await createAuthRouteClient();
    return {
      signOut: (options: { scope: "local" }) => supabase.auth.signOut(options),
    };
  },
  (request, mode) => getTrustedAppOriginForRequest(request, mode),
);

export function POST(request: Request) {
  return postLogout(request);
}
