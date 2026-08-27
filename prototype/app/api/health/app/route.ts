export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const noStoreHeaders = {
  "Cache-Control": "no-store",
};

export async function GET() {
  return Response.json(
    { status: "healthy" },
    { status: 200, headers: noStoreHeaders },
  );
}
