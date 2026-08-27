export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = {
  "Cache-Control": "no-store",
};

export async function GET() {
  return Response.json(
    { status: "unhealthy" },
    { status: 503, headers: noStoreHeaders },
  );
}
