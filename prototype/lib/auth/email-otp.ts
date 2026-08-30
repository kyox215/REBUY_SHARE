export const EMAIL_OTP_ACTIONS = ["request", "verify", "resend"] as const;
export type EmailOtpAction = (typeof EMAIL_OTP_ACTIONS)[number];

export const EMAIL_OTP_LENGTH = 6;
export const EMAIL_OTP_MAX_EMAIL_LENGTH = 254;
export const SYNTHETIC_EMAIL_DOMAIN = "rebuy.test";

const emailPattern = new RegExp(`^[^\\s@]+@${SYNTHETIC_EMAIL_DOMAIN.replace(".", "\\.")}$`, "i");
const otpPattern = new RegExp(`^\\d{${EMAIL_OTP_LENGTH}}$`);

export type EmailOtpInput =
  | { action: "request" | "resend"; email: string }
  | { action: "verify"; email: string; token: string };

export type EmailOtpAuthResult = { error?: unknown } | null | undefined;

export type EmailOtpAuthAdapter = {
  signInWithOtp: (credentials: {
    email: string;
    options: { shouldCreateUser: true };
  }) => Promise<EmailOtpAuthResult>;
  verifyOtp: (credentials: {
    email: string;
    token: string;
    type: "email";
  }) => Promise<EmailOtpAuthResult>;
};

export const EMAIL_OTP_ERROR_CODES = [
  "invalid_input",
  "request_failed",
  "verify_failed",
  "resend_failed",
] as const;
export type EmailOtpErrorCode = (typeof EMAIL_OTP_ERROR_CODES)[number];

export type EmailOtpOutcome =
  | {
      kind: "success";
      action: EmailOtpAction;
      status: "otp_sent" | "verified";
    }
  | { kind: "error"; code: EmailOtpErrorCode; action?: EmailOtpAction };

export type ParsedEmailOtpInput =
  | { ok: true; input: EmailOtpInput }
  | { ok: false };

function hasExactKeys(value: Record<string, unknown>, keys: string[]) {
  const actualKeys = Object.keys(value).sort();
  return (
    actualKeys.length === keys.length &&
    actualKeys.every((key, index) => key === [...keys].sort()[index])
  );
}

export function normalizeSyntheticEmail(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim().toLowerCase();
  const atIndex = normalized.lastIndexOf("@");
  const localPart = atIndex > 0 ? normalized.slice(0, atIndex) : "";

  if (
    normalized.length > EMAIL_OTP_MAX_EMAIL_LENGTH ||
    localPart.length > 64 ||
    !emailPattern.test(normalized)
  ) {
    return null;
  }

  return normalized;
}

export function isSyntheticEmail(value: unknown): value is string {
  return normalizeSyntheticEmail(value) !== null;
}

export function parseEmailOtpInput(value: unknown): ParsedEmailOtpInput {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return { ok: false };
  }

  const record = value as Record<string, unknown>;
  const actionValue = record.action;
  if (
    typeof actionValue !== "string" ||
    !EMAIL_OTP_ACTIONS.includes(actionValue as EmailOtpAction)
  ) {
    return { ok: false };
  }
  const action = actionValue as EmailOtpAction;

  const email = normalizeSyntheticEmail(record.email);
  if (!email) {
    return { ok: false };
  }

  if (action === "verify") {
    if (!hasExactKeys(record, ["action", "email", "token"])) {
      return { ok: false };
    }

    if (typeof record.token !== "string" || !otpPattern.test(record.token)) {
      return { ok: false };
    }

    return {
      ok: true,
      input: { action, email, token: record.token },
    };
  }

  if (!hasExactKeys(record, ["action", "email"])) {
    return { ok: false };
  }

  return { ok: true, input: { action, email } };
}

export async function executeEmailOtp(
  input: EmailOtpInput,
  adapter: EmailOtpAuthAdapter,
): Promise<EmailOtpOutcome> {
  try {
    if (input.action === "verify") {
      const result = await adapter.verifyOtp({
        email: input.email,
        token: input.token,
        type: "email",
      });

      if (!result || result.error) {
        return { kind: "error", action: input.action, code: "verify_failed" };
      }

      return { kind: "success", action: input.action, status: "verified" };
    }

    const result = await adapter.signInWithOtp({
      email: input.email,
      options: { shouldCreateUser: true },
    });

    if (!result || result.error) {
      return {
        kind: "error",
        action: input.action,
        code: input.action === "resend" ? "resend_failed" : "request_failed",
      };
    }

    return { kind: "success", action: input.action, status: "otp_sent" };
  } catch {
    return {
      kind: "error",
      action: input.action,
      code: input.action === "verify"
        ? "verify_failed"
        : input.action === "resend"
          ? "resend_failed"
          : "request_failed",
    };
  }
}

export async function runEmailOtp(
  value: unknown,
  adapter: EmailOtpAuthAdapter,
): Promise<EmailOtpOutcome> {
  const parsed = parseEmailOtpInput(value);
  if (!parsed.ok) {
    return { kind: "error", code: "invalid_input" };
  }

  return executeEmailOtp(parsed.input, adapter);
}
