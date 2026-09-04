import { createAuthCallbackGetHandler } from "@/lib/auth/route-composition";
import { exchangeAndPersistSession } from "@/lib/auth/callback-session";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthCallbackClients } from "@/lib/supabase/server";
import { getTrustedAppOriginForRequest } from "@/lib/auth/server-origin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const getAuthCallback = createAuthCallbackGetHandler(
  (request) => getAuthRuntimeMode(request),
  async (code, flowId) => {
    const { exchange, persistence } = await createAuthCallbackClients(flowId);
    const outcome = await exchangeAndPersistSession(
      () =>
        exchange.auth.exchangeCodeForSession(
          code,
          flowId ? { flowId } : undefined,
        ),
      (tokens) => persistence.auth.setSession(tokens),
    );

    return outcome.kind === "success" ? { error: null } : { error: outcome.code };
  },
  undefined,
  (request, mode) => getTrustedAppOriginForRequest(request, mode),
);

export function GET(request: Request) {
  return getAuthCallback(request);
}
