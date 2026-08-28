import { decideAuthCallback } from "@/lib/auth/callback";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const redirectHeaders = {
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
};

function redirectResponse(target: URL) {
  const headers = new Headers(redirectHeaders);
  headers.set("Location", target.toString());

  return new Response(null, {
    status: 303,
    headers,
  });
}

function loginRedirect(requestUrl: URL, code: string) {
  const target = new URL("/account/login", requestUrl);
  target.searchParams.set("auth_error", code);
  target.hash = "";

  return redirectResponse(target);
}

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const searchParams = requestUrl.searchParams;
  const decision = await decideAuthCallback({
    code: searchParams.get("code"),
    error: searchParams.get("error"),
    errorDescription: searchParams.get("error_description"),
    next: searchParams.get("next"),
    exchange: async (code) => {
      const supabase = await createClient();
      return supabase.auth.exchangeCodeForSession(code);
    },
  });

  if (decision.kind === "error") {
    return loginRedirect(requestUrl, decision.code);
  }

  const target = new URL(decision.next, requestUrl);
  if (target.origin !== requestUrl.origin) {
    return loginRedirect(requestUrl, "exchange_error");
  }

  return redirectResponse(target);
}
