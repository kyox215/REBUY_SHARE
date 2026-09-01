import type { CookieMethodsServer, CookieOptions } from "@supabase/ssr";

import { REBUY_AUTH_COOKIE_NAME } from "../supabase/config";
import type { ServerCookieStore } from "../supabase/cookies";

export const REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME =
  `${REBUY_AUTH_COOKIE_NAME}-code-verifier`;
export const REBUY_PKCE_FLOW_INDEX_COOKIE_NAME =
  `${REBUY_AUTH_COOKIE_NAME}-flows-code-verifier`;

const PKCE_FLOW_ID_PATTERN = /^[a-zA-Z0-9_-]{8,64}$/;

type CookieToSet = {
  name: string;
  value: string;
  options: CookieOptions;
};

/** Mirrors auth-js 2.112.4 before a URL value can become a cookie key. */
export function isValidPkceFlowId(value: unknown): value is string {
  return typeof value === "string" && PKCE_FLOW_ID_PATTERN.test(value);
}

export function getRebuyPkceFlowSlotCookieName(flowId: string) {
  if (!isValidPkceFlowId(flowId)) {
    throw new Error("Invalid callback flow identifier.");
  }

  return `${REBUY_AUTH_COOKIE_NAME}-flow-${flowId}-code-verifier`;
}

function getAllowedPkceCookieNames(flowId?: string) {
  if (flowId === undefined) {
    return [REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME];
  }

  return [
    getRebuyPkceFlowSlotCookieName(flowId),
    REBUY_PKCE_FLOW_INDEX_COOKIE_NAME,
    REBUY_PKCE_CODE_VERIFIER_COOKIE_NAME,
  ];
}

function isExactPkceDeletion(cookie: CookieToSet) {
  return (
    cookie.value === "" &&
    cookie.options.maxAge === 0 &&
    cookie.options.path === "/" &&
    cookie.options.sameSite === "lax" &&
    cookie.options.secure === false
  );
}

/**
 * Keep the callback exchange ephemeral. A legacy callback reads only the
 * legacy verifier; a flow-aware callback may also read its exact slot and the
 * auth-js flow index. All other cookie names, chunks, and non-deletion writes
 * stay outside the exchange client's persistence boundary.
 */
export function createEphemeralExchangeCookieMethods(
  cookieStore: ServerCookieStore,
  flowId?: string,
): Pick<CookieMethodsServer, "getAll" | "setAll"> {
  const allowedCookieNames = new Set(getAllowedPkceCookieNames(flowId));

  return {
    getAll() {
      return cookieStore.getAll().filter(({ name }) => allowedCookieNames.has(name));
    },
    setAll(cookiesToSet: CookieToSet[]) {
      for (const cookie of cookiesToSet) {
        if (allowedCookieNames.has(cookie.name) && isExactPkceDeletion(cookie)) {
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

function isUsableToken(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function extractSessionTokens(value: unknown): CallbackSessionTokens | null {
  if (!isRecord(value) || value.error != null) {
    return null;
  }

  const data = value.data;
  if (!isRecord(data) || !isRecord(data.session)) {
    return null;
  }

  const accessToken = data.session.access_token;
  const refreshToken = data.session.refresh_token;
  if (
    !isUsableToken(accessToken) ||
    !isUsableToken(refreshToken)
  ) {
    return null;
  }

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
  };
}

function hasUsablePersistedSession(value: unknown) {
  if (!isRecord(value) || value.error != null) {
    return false;
  }

  const data = value.data;
  const session = isRecord(data) ? data.session : null;
  return (
    isRecord(session) &&
    isUsableToken(session.access_token) &&
    isUsableToken(session.refresh_token)
  );
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
    if (!hasUsablePersistedSession(persistenceResult)) {
      return { kind: "error", code: "persistence_failed" };
    }
  } catch {
    return { kind: "error", code: "persistence_failed" };
  }

  return { kind: "success" };
}
