import { createEmailOtpPostHandler } from "@/lib/auth/route-composition";
import { getAuthRuntimeMode } from "@/lib/auth/runtime-mode";
import { createAuthRouteClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const postEmailOtp = createEmailOtpPostHandler(
  (request) => getAuthRuntimeMode(request),
  async () => {
    const supabase = await createAuthRouteClient();

    return {
      signInWithOtp: ({ email, options }: { email: string; options: { shouldCreateUser: true } }) =>
        supabase.auth.signInWithOtp({ email, options }),
      verifyOtp: ({ email, token, type }: { email: string; token: string; type: "email" }) =>
        supabase.auth.verifyOtp({ email, token, type }),
    };
  },
);

export function POST(request: Request) {
  return postEmailOtp(request);
}
