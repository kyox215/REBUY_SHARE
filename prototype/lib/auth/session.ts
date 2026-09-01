export type SessionClaimsResult = {
  data?: { claims?: unknown | null } | null;
  error?: unknown | null;
} | null | undefined;

export type SessionClaimsAdapter = {
  getClaims: () => Promise<SessionClaimsResult>;
};

export type SessionStatus =
  | { status: "authenticated" }
  | { status: "anonymous" }
  | { status: "error" };

function hasClaims(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

export async function resolveSessionStatus(
  adapter: SessionClaimsAdapter,
): Promise<SessionStatus> {
  try {
    const result = await adapter.getClaims();
    if (!result || result.error) {
      return { status: "error" };
    }

    return result.data?.claims && hasClaims(result.data.claims)
      ? { status: "authenticated" }
      : { status: "anonymous" };
  } catch {
    return { status: "error" };
  }
}
