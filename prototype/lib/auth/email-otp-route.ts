import {
  executeEmailOtp,
  normalizeSyntheticEmail,
  parseEmailOtpInput,
  type EmailNormalizer,
  type EmailOtpAuthAdapter,
  type EmailOtpOutcome,
} from "./email-otp";
import { LOCAL_APP_HOST, LOCAL_APP_ORIGIN } from "./app-origin";
import { authUnavailableResponse } from "./auth-unavailable";
import type { AuthRuntimeMode } from "./runtime-mode-core";

export const EMAIL_OTP_MAX_BODY_BYTES = 1024;
export const EMAIL_OTP_APP_ORIGIN = LOCAL_APP_ORIGIN;
export const EMAIL_OTP_APP_HOST = LOCAL_APP_HOST;

const noStoreHeaders = {
  "Cache-Control": "no-store",
  Pragma: "no-cache",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

export type EmailOtpAuthAdapterFactory = (context?: { appOrigin: string }) =>
  | EmailOtpAuthAdapter
  | Promise<EmailOtpAuthAdapter>;

export type EmailOtpRequestPolicy = {
  appOrigin: string;
  normalizeEmail: EmailNormalizer;
  isAllowed: (email: string) => boolean;
  concealDeniedRequests: boolean;
};

const localEmailOtpPolicy: EmailOtpRequestPolicy = {
  appOrigin: EMAIL_OTP_APP_ORIGIN,
  normalizeEmail: normalizeSyntheticEmail,
  isAllowed: () => true,
  concealDeniedRequests: false,
};

type BodyReadResult =
  | { ok: true; value: unknown }
  | { ok: false; status: 400 | 413 };

function jsonResponse(
  body: Record<string, string>,
  status: number,
) {
  return Response.json(body, { status, headers: noStoreHeaders });
}

function isSameOrigin(request: Request, appOrigin: string) {
  const origin = request.headers.get("origin");
  const host = request.headers.get("host");
  if (!origin || !host) {
    return false;
  }

  try {
    const requestOrigin = new URL(request.url).origin;
    return (
      requestOrigin === appOrigin &&
      origin === appOrigin &&
      host === new URL(appOrigin).host
    );
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
    if (!/^\d+$/.test(contentLength)) {
      return { ok: false, status: 400 };
    }

    const byteLength = Number(contentLength);
    if (!Number.isSafeInteger(byteLength) || byteLength > EMAIL_OTP_MAX_BODY_BYTES) {
      return { ok: false, status: 413 };
    }
  }

  const body = request.body;
  if (!body) {
    return { ok: false, status: 400 };
  }

  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }

      if (!(value instanceof Uint8Array)) {
        return { ok: false, status: 400 };
      }

      totalBytes += value.byteLength;
      if (totalBytes > EMAIL_OTP_MAX_BODY_BYTES) {
        try {
          await reader.cancel();
        } catch {
          // The body is already rejected; cancellation is best effort.
        }
        return { ok: false, status: 413 };
      }

      chunks.push(value);
    }
  } catch {
    return { ok: false, status: 400 };
  } finally {
    reader.releaseLock();
  }

  const bodyBytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bodyBytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  let text: string;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bodyBytes);
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

  if (outcome.code === "rate_limited") {
    return jsonResponse({ status: "error", code: outcome.code }, 429);
  }

  if (outcome.code === "verify_failed") {
    return jsonResponse({ status: "error", code: outcome.code }, 422);
  }

  return jsonResponse({ status: "error", code: outcome.code }, 502);
}

export async function handleEmailOtpRequest(
  request: Request,
  createAuthAdapter: EmailOtpAuthAdapterFactory,
  policy: EmailOtpRequestPolicy = localEmailOtpPolicy,
) {
  if (!isSameOrigin(request, policy.appOrigin)) {
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

  const parsed = parseEmailOtpInput(body.value, policy.normalizeEmail);
  if (!parsed.ok) {
    return jsonResponse({ status: "error", code: "invalid_request" }, 400);
  }

  if (!policy.isAllowed(parsed.input.email)) {
    if (
      policy.concealDeniedRequests &&
      (parsed.input.action === "request" || parsed.input.action === "resend")
    ) {
      return jsonResponse({ status: "otp_sent" }, 200);
    }
    return jsonResponse({ status: "error", code: "verify_failed" }, 422);
  }

  let adapter: EmailOtpAuthAdapter;
  try {
    adapter = await createAuthAdapter({ appOrigin: policy.appOrigin });
  } catch {
    return jsonResponse({ status: "error", code: "server_error" }, 500);
  }

  const outcome = await executeEmailOtp(parsed.input, adapter);
  return outcomeResponse(outcome);
}

export async function handleEmailOtpRequestForMode(
  request: Request,
  mode: AuthRuntimeMode,
  createAuthAdapter: EmailOtpAuthAdapterFactory,
  policy?: EmailOtpRequestPolicy,
) {
  if (mode === "ui-only" || !policy) {
    if (mode === "local-auth") {
      return handleEmailOtpRequest(request, createAuthAdapter, localEmailOtpPolicy);
    }
    return authUnavailableResponse();
  }

  return handleEmailOtpRequest(request, createAuthAdapter, policy);
}
