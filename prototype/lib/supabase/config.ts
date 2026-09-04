import type { CookieOptionsWithName } from "@supabase/ssr";

export const LOCAL_SUPABASE_URL = "http://127.0.0.1:55321/";
export const REBUY_AUTH_COOKIE_NAME = "rebuy-g2-a1-e2a-auth-token";
export const REBUY_AUTH_COOKIE_OPTIONS = {
  name: REBUY_AUTH_COOKIE_NAME,
  path: "/",
  sameSite: "lax",
  secure: false,
} as const satisfies CookieOptionsWithName;

export type SupabaseRuntimeMode = "local-auth" | "hosted-auth";

export type SupabasePublicConfig = {
  url: string;
  publishableKey: string;
  runtimeMode: SupabaseRuntimeMode;
};

const modernPublishableKeyPattern = /^sb_publishable_[A-Za-z0-9_-]+$/;
const base64UrlPattern = /^[A-Za-z0-9_-]+$/;

function decodeBase64Url(value: string): string | null {
  if (!base64UrlPattern.test(value)) {
    return null;
  }

  try {
    const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(
      Math.ceil(value.length / 4) * 4,
      "=",
    );
    const bytes = Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
    return new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    return null;
  }
}

function isLegacyAnonJwt(value: string) {
  const segments = value.split(".");
  if (segments.length !== 3 || segments.some((segment) => !base64UrlPattern.test(segment))) {
    return false;
  }

  const headerText = decodeBase64Url(segments[0]);
  const payloadText = decodeBase64Url(segments[1]);
  if (!headerText || !payloadText) {
    return false;
  }

  try {
    const header = JSON.parse(headerText) as unknown;
    const payload = JSON.parse(payloadText) as unknown;
    return (
      !!header &&
      typeof header === "object" &&
      !Array.isArray(header) &&
      typeof (header as { alg?: unknown }).alg === "string" &&
      (header as { alg: string }).alg.length > 0 &&
      !!payload &&
      typeof payload === "object" &&
      !Array.isArray(payload) &&
      (payload as { role?: unknown }).role === "anon"
    );
  } catch {
    return false;
  }
}

export function isAllowedSupabasePublicKey(value: unknown): value is string {
  if (typeof value !== "string" || value.length === 0) {
    return false;
  }

  if (modernPublishableKeyPattern.test(value)) {
    return true;
  }

  return isLegacyAnonJwt(value);
}

export class SupabaseConfigError extends Error {
  constructor() {
    super("Supabase configuration is invalid.");
    this.name = "SupabaseConfigError";
  }
}

function normalizeHostedSupabaseUrl(value: unknown) {
  if (typeof value !== "string" || value.length > 100) {
    return null;
  }

  try {
    const url = new URL(value);
    if (
      url.protocol !== "https:" ||
      url.username !== "" ||
      url.password !== "" ||
      url.port !== "" ||
      url.pathname !== "/" ||
      url.search !== "" ||
      url.hash !== "" ||
      !/^[a-z0-9]{20}\.supabase\.co$/.test(url.hostname)
    ) {
      return null;
    }
    return `${url.origin}/`;
  } catch {
    return null;
  }
}

export function getRebuyAuthCookieOptions(runtimeMode: SupabaseRuntimeMode) {
  return {
    ...REBUY_AUTH_COOKIE_OPTIONS,
    secure: runtimeMode === "hosted-auth",
  } as const satisfies CookieOptionsWithName;
}

export function validateSupabaseConfig(
  url: unknown,
  publishableKey: unknown,
): SupabasePublicConfig {
  if (!isAllowedSupabasePublicKey(publishableKey)) {
    throw new SupabaseConfigError();
  }

  if (url === LOCAL_SUPABASE_URL) {
    return {
      url: LOCAL_SUPABASE_URL,
      publishableKey,
      runtimeMode: "local-auth",
    };
  }

  const hostedUrl = normalizeHostedSupabaseUrl(url);
  if (!hostedUrl || !modernPublishableKeyPattern.test(publishableKey)) {
    throw new SupabaseConfigError();
  }

  return {
    url: hostedUrl,
    publishableKey,
    runtimeMode: "hosted-auth",
  };
}
