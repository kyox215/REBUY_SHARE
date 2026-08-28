const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u;
const FORMAT_CHARACTER_PATTERN = /[\u061c\u200b-\u200f\u202a-\u202e\u2060-\u2064\u2066-\u206f\ufeff]/u;
const SCHEME_PREFIX_PATTERN = /^[a-z][a-z\d+.-]*:/iu;
const WHITESPACE_PATTERN = /\s/u;
const NON_ASCII_WHITESPACE_PATTERN = /\s/u;
const MAX_DECODE_PASSES = 3;

export const MAX_SAFE_NEXT_LENGTH = 2048;
export const MAX_SAFE_NEXT_DECODE_PASSES = MAX_DECODE_PASSES;

const hasDotSegment = (value: string) => {
  const path = value.split(/[?#]/u, 1)[0];
  return /(?:^|\/)\.{1,2}(?:\/|$)/u.test(path);
};

const hasDisallowedWhitespace = (value: string) =>
  Array.from(value).some(
    (character) =>
      NON_ASCII_WHITESPACE_PATTERN.test(character) && character !== " ",
  );

const hasUnsafeCharacters = (value: string) =>
  CONTROL_CHARACTER_PATTERN.test(value) ||
  FORMAT_CHARACTER_PATTERN.test(value) ||
  value.includes("\\") ||
  hasDotSegment(value);

const hasUnsafeRawCharacters = (value: string) =>
  hasUnsafeCharacters(value) || WHITESPACE_PATTERN.test(value);

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
  if (
    typeof candidate !== "string" ||
    candidate.length === 0 ||
    candidate.length > MAX_SAFE_NEXT_LENGTH
  ) {
    return "/";
  }

  if (
    hasUnsafeRawCharacters(candidate) ||
    !candidate.startsWith("/") ||
    candidate.startsWith("//")
  ) {
    return "/";
  }

  let decoded = candidate;
  let stabilized = false;

  for (let pass = 0; pass < MAX_DECODE_PASSES; pass += 1) {
    const next = decodeSafely(decoded);

    if (
      next === null ||
      next.length > MAX_SAFE_NEXT_LENGTH ||
      hasUnsafeCharacters(next) ||
      hasDisallowedWhitespace(next)
    ) {
      return "/";
    }

    if (next === decoded) {
      stabilized = true;
      break;
    }

    decoded = next;

    if (decoded.startsWith("//") || SCHEME_PREFIX_PATTERN.test(decoded)) {
      return "/";
    }
  }

  if (
    !stabilized ||
    decoded.startsWith("//") ||
    SCHEME_PREFIX_PATTERN.test(decoded)
  ) {
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
