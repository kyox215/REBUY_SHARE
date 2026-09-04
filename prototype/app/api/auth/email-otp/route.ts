import { createEmailOtpPostHandler } from "@/lib/auth/route-composition";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthRouteClient } from "@/lib/supabase/server";
import { getEmailOtpAccessPolicy } from "@/lib/auth/server-email-policy";
import {
  getTrustedAppOriginForRequest,
} from "@/lib/auth/server-origin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const postEmailOtp = createEmailOtpPostHandler(
  (request) => getAuthRuntimeMode(request),
  async (context) => {
    const supabase = await createAuthRouteClient();
    if (!context?.appOrigin) throw new Error("auth_origin_unavailable");

    return {
      signInWithOtp: ({ email, options }: { email: string; options: { shouldCreateUser: boolean } }) =>
        supabase.auth.signInWithOtp({
          email,
          options: {
            ...options,
            emailRedirectTo: `${context.appOrigin}/auth/callback`,
          },
        }),
      verifyOtp: ({ email, token, type }: { email: string; token: string; type: "email" }) =>
        supabase.auth.verifyOtp({ email, token, type }),
    };
  },
  (request, mode) => {
    const appOrigin = getTrustedAppOriginForRequest(request, mode);
    if (!appOrigin) return undefined;
    return { ...getEmailOtpAccessPolicy(mode), appOrigin };
  },
);

export function POST(request: Request) {
  return postEmailOtp(request);
}
