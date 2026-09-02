import { createAuthCallbackGetHandler } from "@/lib/auth/route-composition";
import { exchangeAndPersistSession } from "@/lib/auth/callback-session";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthCallbackClients } from "@/lib/supabase/server";

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
);

export function GET(request: Request) {
  return getAuthCallback(request);
}
