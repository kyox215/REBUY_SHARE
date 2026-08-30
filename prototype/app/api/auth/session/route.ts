import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
};

export async function GET() {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.getClaims();

    if (error || !data?.claims) {
      return Response.json(
        { status: "anonymous" },
        { status: 401, headers: noStoreHeaders },
      );
    }

    return Response.json(
      { status: "authenticated" },
      { status: 200, headers: noStoreHeaders },
    );
  } catch {
    return Response.json(
      { status: "anonymous" },
      { status: 401, headers: noStoreHeaders },
    );
  }
}
