import { SupabaseConfigError } from "@/lib/supabase/config";
import { getSupabaseServerConfig } from "@/lib/supabase/server-config";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = {
  "Cache-Control": "no-store",
};

function jsonHealth(
  configured: boolean,
  reachable: boolean,
  status: 200 | 502 | 503,
) {
  return Response.json(
    { configured, reachable, status },
    { status, headers: noStoreHeaders },
  );
}

export async function GET() {
  let config: ReturnType<typeof getSupabaseServerConfig>;

  try {
    config = getSupabaseServerConfig();
  } catch (error) {
    if (error instanceof SupabaseConfigError) {
      return jsonHealth(false, false, 503);
    }

    return jsonHealth(false, false, 503);
  }

  try {
    const response = await fetch(new URL("/auth/v1/settings", config.url), {
      headers: {
        Accept: "application/json",
        apikey: config.publishableKey,
      },
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      return jsonHealth(true, false, 502);
    }

    return jsonHealth(true, true, 200);
  } catch {
    return jsonHealth(true, false, 502);
  }
}
