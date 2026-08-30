import { handleAuthCallback } from "@/lib/auth/callback-route";
import { exchangeAndPersistSession } from "@/lib/auth/callback-session";
import { createAuthCallbackClients } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  return handleAuthCallback(request, async (code) => {
    const { exchange, persistence } = await createAuthCallbackClients();
    const outcome = await exchangeAndPersistSession(
      () => exchange.auth.exchangeCodeForSession(code),
      (tokens) => persistence.auth.setSession(tokens),
    );

    return outcome.kind === "success" ? { error: null } : { error: outcome.code };
  });
}
