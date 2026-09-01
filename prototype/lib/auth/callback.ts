import { normalizeSafeNext } from "./redirect";

export const AUTH_CALLBACK_CODE_MAX_LENGTH = 4096;

const AUTH_CALLBACK_CODE_CONTROL_PATTERN =
  /[\u0000-\u001f\u007f-\u009f\u061c\u200b-\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f\ufeff]/u;
const AUTH_CALLBACK_CODE_WHITESPACE_PATTERN = /\s/u;

export const AUTH_CALLBACK_ERROR_CODES = [
  "provider_error",
  "missing_code",
  "invalid_code",
  "exchange_failed",
  "exchange_error",
] as const;

export type AuthCallbackErrorCode = (typeof AUTH_CALLBACK_ERROR_CODES)[number];

export const AUTH_CALLBACK_ERROR_MESSAGES: Readonly<
  Record<AuthCallbackErrorCode, string>
> = {
  provider_error: "登录未完成，请重新尝试。",
  missing_code: "登录链接无效，请重新开始。",
  invalid_code: "登录链接格式无效，请重新开始。",
  exchange_failed: "登录链接已失效，请重新开始。",
  exchange_error: "暂时无法完成登录，请稍后重试。",
};

export function isAuthCallbackErrorCode(
  value: unknown,
): value is AuthCallbackErrorCode {
  return (
    typeof value === "string" &&
    AUTH_CALLBACK_ERROR_CODES.includes(value as AuthCallbackErrorCode)
  );
}

export type AuthCallbackDecision =
  | { kind: "success"; next: string }
  | { kind: "error"; code: AuthCallbackErrorCode; next: string };

export type AuthCodeExchange = (
  code: string,
  flowId?: string,
) => Promise<{ error?: unknown } | null | undefined>;

export type AuthCallbackInput = {
  code?: unknown;
  error?: unknown;
  errorDescription?: unknown;
  next?: unknown;
  flowId?: string;
  exchange: AuthCodeExchange;
};

const hasProviderError = (value: unknown) =>
  typeof value === "string" && value.trim().length > 0;

const errorDecision = (
  code: AuthCallbackErrorCode,
  next: string,
): AuthCallbackDecision => ({
  kind: "error",
  code,
  next,
});

/**
 * Decide the safe outcome of a PKCE callback without exposing provider data.
 * The exchange function is injected so this policy can be tested without a
 * Supabase request. It is invoked at most once, and only for a valid code no
 * longer than AUTH_CALLBACK_CODE_MAX_LENGTH. Invalid code input never reaches
 * the exchange function.
 */
export async function decideAuthCallback({
  code,
  error,
  errorDescription,
  next,
  flowId,
  exchange,
}: AuthCallbackInput): Promise<AuthCallbackDecision> {
  const safeNext = normalizeSafeNext(next);

  if (hasProviderError(error) || hasProviderError(errorDescription)) {
    return errorDecision("provider_error", safeNext);
  }

  if (typeof code !== "string" || code.trim().length === 0) {
    return errorDecision("missing_code", safeNext);
  }

  if (
    code.length > AUTH_CALLBACK_CODE_MAX_LENGTH ||
    code !== code.trim() ||
    AUTH_CALLBACK_CODE_WHITESPACE_PATTERN.test(code) ||
    AUTH_CALLBACK_CODE_CONTROL_PATTERN.test(code)
  ) {
    return errorDecision("invalid_code", safeNext);
  }

  try {
    const result = await exchange(code, flowId);

    if (!result || result.error) {
      return errorDecision("exchange_failed", safeNext);
    }
  } catch {
    return errorDecision("exchange_error", safeNext);
  }

  return { kind: "success", next: safeNext };
}
