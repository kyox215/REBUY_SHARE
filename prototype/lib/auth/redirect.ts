const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u;
const SCHEME_PREFIX_PATTERN = /^[a-z][a-z\d+.-]*:/iu;
const MAX_DECODE_PASSES = 3;

const hasUnsafeCharacters = (value: string) =>
  CONTROL_CHARACTER_PATTERN.test(value) || value.includes("\\");

const decodeSafely = (value: string) => {
  try {
    return decodeURIComponent(value);
  } catch {
    return null;
  }
};

/**
 * Keep callback destinations on this app's origin.
 *
 * The value is validated through a few decode passes so encoded and
 * double-encoded protocol-relative paths cannot become external redirects.
 * The original value is returned after validation so query and hash encoding
 * remain unchanged for the browser.
 */
export function normalizeSafeNext(candidate: unknown): string {
  if (typeof candidate !== "string" || candidate.length === 0) {
    return "/";
  }

  if (
    hasUnsafeCharacters(candidate) ||
    !candidate.startsWith("/") ||
    candidate.startsWith("//")
  ) {
    return "/";
  }

  let decoded = candidate;
  for (let pass = 0; pass < MAX_DECODE_PASSES; pass += 1) {
    const next = decodeSafely(decoded);

    if (next === null || hasUnsafeCharacters(next)) {
      return "/";
    }

    if (next === decoded) {
      break;
    }

    decoded = next;

    if (decoded.startsWith("//") || SCHEME_PREFIX_PATTERN.test(decoded)) {
      return "/";
    }
  }

  if (decoded.startsWith("//") || SCHEME_PREFIX_PATTERN.test(decoded)) {
    return "/";
  }

  try {
    const base = new URL("https://rebuy.local/");
    const parsed = new URL(candidate, base);

    if (parsed.origin !== base.origin || !parsed.pathname.startsWith("/")) {
      return "/";
    }
  } catch {
    return "/";
  }

  return candidate;
}
