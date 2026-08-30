import {
  handleEmailOtpRequest,
} from "@/lib/auth/email-otp-route";
import { createClient } from "@/lib/supabase/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  return handleEmailOtpRequest(request, async () => {
    const supabase = await createClient();

    return {
      signInWithOtp: ({ email, options }: { email: string; options: { shouldCreateUser: true } }) =>
        supabase.auth.signInWithOtp({ email, options }),
      verifyOtp: ({ email, token, type }: { email: string; token: string; type: "email" }) =>
        supabase.auth.verifyOtp({ email, token, type }),
    };
  });
}
