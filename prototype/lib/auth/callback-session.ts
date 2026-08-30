import type { CookieMethodsServer, CookieOptions } from "@supabase/ssr";

import { REBUY_AUTH_COOKIE_NAME } from "../supabase/config";
import type { ServerCookieStore } from "../supabase/cookies";

export const REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME =
  `${REBUY_AUTH_COOKIE_NAME}-code-verifier`;

type CookieToSet = {
  name: string;
  value: string;
  options: CookieOptions;
};

/**
 * Keep the callback exchange ephemeral: only the fixed PKCE verifier cookie
 * can be read, and only its exact deletion can be written.
 */
export function createEphemeralExchangeCookieMethods(
  cookieStore: ServerCookieStore,
): Pick<CookieMethodsServer, "getAll" | "setAll"> {
  return {
    getAll() {
      return cookieStore
        .getAll()
        .filter(({ name }) => name === REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME);
    },
    setAll(cookiesToSet: CookieToSet[]) {
      for (const cookie of cookiesToSet) {
        if (
          cookie.name === REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME &&
          cookie.value === "" &&
          cookie.options.maxAge === 0
        ) {
          cookieStore.set(cookie.name, cookie.value, cookie.options);
        }
      }
    },
  };
}

export type CallbackSessionTokens = {
  access_token: string;
  refresh_token: string;
};

export const AUTH_CALLBACK_SESSION_ERROR_CODES = [
  "exchange_failed",
  "missing_tokens",
  "persistence_failed",
] as const;

export type AuthCallbackSessionErrorCode =
  (typeof AUTH_CALLBACK_SESSION_ERROR_CODES)[number];

export type AuthCallbackSessionOutcome =
  | { kind: "success" }
  | { kind: "error"; code: AuthCallbackSessionErrorCode };

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function extractSessionTokens(value: unknown): CallbackSessionTokens | null {
  if (!isRecord(value) || value.error) {
    return null;
  }

  const data = value.data;
  if (!isRecord(data) || !isRecord(data.session)) {
    return null;
  }

  const accessToken = data.session.access_token;
  const refreshToken = data.session.refresh_token;
  if (
    typeof accessToken !== "string" ||
    accessToken.length === 0 ||
    typeof refreshToken !== "string" ||
    refreshToken.length === 0
  ) {
    return null;
  }

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
  };
}

/**
 * Coordinate an OAuth code exchange without returning or persisting the
 * provider session object. The persistence callback receives exactly two
 * Supabase session fields.
 */
export async function exchangeAndPersistSession(
  exchange: () => Promise<unknown>,
  persistSession: (tokens: CallbackSessionTokens) => Promise<unknown>,
): Promise<AuthCallbackSessionOutcome> {
  let exchangeResult: unknown;
  try {
    exchangeResult = await exchange();
  } catch {
    return { kind: "error", code: "exchange_failed" };
  }

  const tokens = extractSessionTokens(exchangeResult);
  if (!tokens) {
    return {
      kind: "error",
      code: isRecord(exchangeResult) && exchangeResult.error
        ? "exchange_failed"
        : "missing_tokens",
    };
  }

  try {
    const persistenceResult = await persistSession(tokens);
    if (!isRecord(persistenceResult) || persistenceResult.error) {
      return { kind: "error", code: "persistence_failed" };
    }
  } catch {
    return { kind: "error", code: "persistence_failed" };
  }

  return { kind: "success" };
}
