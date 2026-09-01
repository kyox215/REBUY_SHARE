import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAppHealthGetHandler } from "@/lib/health/route-composition";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const getAppHealth = createAppHealthGetHandler(
  (request) => getAuthRuntimeMode(request),
);

export function GET(request: Request) {
  return getAppHealth(request);
}
