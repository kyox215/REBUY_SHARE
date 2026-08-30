import {
  executeEmailOtp,
  parseEmailOtpInput,
  type EmailOtpAuthAdapter,
  type EmailOtpOutcome,
} from "./email-otp";

export const EMAIL_OTP_MAX_BODY_BYTES = 1024;

const noStoreHeaders = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

export type EmailOtpAuthAdapterFactory = () =>
  | EmailOtpAuthAdapter
  | Promise<EmailOtpAuthAdapter>;

type BodyReadResult =
  | { ok: true; value: unknown }
  | { ok: false; status: 400 | 413 };

function jsonResponse(
  body: Record<string, string>,
  status: number,
) {
  return Response.json(body, { status, headers: noStoreHeaders });
}

function isSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) {
    return false;
  }

  try {
    const requestUrl = new URL(request.url);
    const requestOrigins = new Set([requestUrl.origin]);
    const host = request.headers.get("host");

    if (host) {
      requestOrigins.add(new URL(`${requestUrl.protocol}//${host}`).origin);
    }

    return requestOrigins.has(new URL(origin).origin);
  } catch {
    return false;
  }
}

function hasJsonContentType(request: Request) {
  const contentType = request.headers.get("content-type");
  if (!contentType) {
    return false;
  }

  return contentType.split(";", 1)[0]?.trim().toLowerCase() === "application/json";
}

async function readJsonBody(request: Request): Promise<BodyReadResult> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^\d+$/.test(contentLength.trim())) {
      return { ok: false, status: 400 };
    }

    const byteLength = Number(contentLength);
    if (!Number.isSafeInteger(byteLength) || byteLength > EMAIL_OTP_MAX_BODY_BYTES) {
      return { ok: false, status: 413 };
    }
  }

  let text: string;
  try {
    text = await request.text();
  } catch {
    return { ok: false, status: 400 };
  }

  if (new TextEncoder().encode(text).byteLength > EMAIL_OTP_MAX_BODY_BYTES) {
    return { ok: false, status: 413 };
  }

  try {
    return { ok: true, value: JSON.parse(text) as unknown };
  } catch {
    return { ok: false, status: 400 };
  }
}

function outcomeResponse(outcome: EmailOtpOutcome) {
  if (outcome.kind === "success") {
    return jsonResponse({ status: outcome.status }, 200);
  }

  if (outcome.code === "invalid_input") {
    return jsonResponse({ status: "error", code: outcome.code }, 400);
  }

  if (outcome.code === "verify_failed") {
    return jsonResponse({ status: "error", code: outcome.code }, 422);
  }

  return jsonResponse({ status: "error", code: outcome.code }, 502);
}

export async function handleEmailOtpRequest(
  request: Request,
  createAuthAdapter: EmailOtpAuthAdapterFactory,
) {
  if (!isSameOrigin(request)) {
    return jsonResponse({ status: "error", code: "origin_not_allowed" }, 403);
  }

  if (!hasJsonContentType(request)) {
    return jsonResponse({ status: "error", code: "unsupported_media_type" }, 415);
  }

  const body = await readJsonBody(request);
  if (!body.ok) {
    return jsonResponse(
      {
        status: "error",
        code: body.status === 413 ? "body_too_large" : "invalid_request",
      },
      body.status,
    );
  }

  const parsed = parseEmailOtpInput(body.value);
  if (!parsed.ok) {
    return jsonResponse({ status: "error", code: "invalid_request" }, 400);
  }

  let adapter: EmailOtpAuthAdapter;
  try {
    adapter = await createAuthAdapter();
  } catch {
    return jsonResponse({ status: "error", code: "server_error" }, 500);
  }

  const outcome = await executeEmailOtp(parsed.input, adapter);
  return outcomeResponse(outcome);
}
