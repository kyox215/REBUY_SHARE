import "server-only";

import {
  normalizeEmail,
  normalizeSyntheticEmail,
  type EmailNormalizer,
} from "./email-otp";
import type { AuthRuntimeMode } from "./runtime-mode-core";

export type EmailOtpAccessPolicy = {
  normalizeEmail: EmailNormalizer;
  isAllowed: (email: string) => boolean;
  concealDeniedRequests: boolean;
};

function readHostedEmailAllowlist() {
  const value = process.env.REBUY_AUTH_ALLOWED_EMAILS;
  if (typeof value !== "string" || value.length === 0 || value.length > 4096) {
    return new Set<string>();
  }

  const entries = value.split(",");
  if (entries.length > 50) {
    return new Set<string>();
  }

  const normalized = entries.map((entry) => normalizeEmail(entry));
  if (normalized.some((entry) => entry === null)) {
    return new Set<string>();
  }
  return new Set(normalized as string[]);
}

export function getEmailOtpAccessPolicy(mode: AuthRuntimeMode): EmailOtpAccessPolicy {
  if (mode === "local-auth") {
    return {
      normalizeEmail: normalizeSyntheticEmail,
      isAllowed: () => true,
      concealDeniedRequests: false,
    };
  }

  const allowlist = readHostedEmailAllowlist();
  return {
    normalizeEmail,
    isAllowed: (email) => allowlist.has(email),
    concealDeniedRequests: true,
  };
}
