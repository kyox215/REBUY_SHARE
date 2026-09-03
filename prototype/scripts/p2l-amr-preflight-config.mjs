const PUBLIC_KEY_PATTERN = /^sb_publishable_[A-Za-z0-9_-]+$/;

export const MIN_REFRESH_AMR_SEPARATION_SECONDS = 2;

export function isSupportedNodeRuntime(version) {
  const match = /^(\d+)\./.exec(version);
  return match !== null && Number.parseInt(match[1], 10) === 22;
}

function isLegacyAnonJwt(value) {
  const parts = value.split(".");
  if (parts.length !== 3 || parts.some((part) => !/^[A-Za-z0-9_-]+$/.test(part))) {
    return false;
  }

  try {
    const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return (
      !!header &&
      typeof header === "object" &&
      !Array.isArray(header) &&
      typeof header.alg === "string" &&
      header.alg.length > 0 &&
      !!payload &&
      typeof payload === "object" &&
      !Array.isArray(payload) &&
      payload.role === "anon"
    );
  } catch {
    return false;
  }
}

export function isAllowedPublicKey(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    (PUBLIC_KEY_PATTERN.test(value) || isLegacyAnonJwt(value))
  );
}

export function selectAllowedPublicKey(status) {
  return [status?.PUBLISHABLE_KEY, status?.ANON_KEY].find(isAllowedPublicKey);
}

export function hasMinimumAmrEpochSeparation(
  currentEpochSeconds,
  initialAmrTimestamp,
) {
  return (
    Number.isSafeInteger(currentEpochSeconds) &&
    currentEpochSeconds > 0 &&
    Number.isSafeInteger(initialAmrTimestamp) &&
    initialAmrTimestamp > 0 &&
    Math.abs(currentEpochSeconds - initialAmrTimestamp) >=
      MIN_REFRESH_AMR_SEPARATION_SECONDS
  );
}
