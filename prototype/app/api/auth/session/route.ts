import { resolveSessionStatus } from "@/lib/auth/session";
import { createAuthRouteClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
};

export async function GET() {
  const session = await resolveSessionStatus({
    getClaims: async () => {
      const supabase = await createAuthRouteClient();
      return supabase.auth.getClaims();
    },
  });

  if (session.status === "authenticated") {
    return Response.json(
      { status: "authenticated" },
      { status: 200, headers: noStoreHeaders },
    );
  }

  if (session.status === "anonymous") {
    return Response.json(
      { status: "anonymous" },
      { status: 401, headers: noStoreHeaders },
    );
  }

  return Response.json(
    { status: "error", code: "session_error" },
    { status: 500, headers: noStoreHeaders },
  );
}
