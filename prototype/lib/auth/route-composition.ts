import {
  handleAuthCallbackForMode,
  type AuthCallbackDecider,
} from "./callback-route";
import {
  handleEmailOtpRequestForMode,
  type EmailOtpAuthAdapterFactory,
  type EmailOtpRequestPolicy,
} from "./email-otp-route";
import {
  handleLogoutRequestForMode,
  type LogoutAuthAdapterFactory,
} from "./logout";
import { handleSessionRequest, type SessionClaimsFactory } from "./session-route";
import type { AuthCodeExchange } from "./callback";
import type { AuthRuntimeMode, AuthRuntimeModeReader } from "./runtime-mode-core";

export type AuthAppOriginReader = (
  request: Request,
  mode: AuthRuntimeMode,
) => string | null;

export type EmailOtpPolicyReader = (
  request: Request,
  mode: AuthRuntimeMode,
) => EmailOtpRequestPolicy | undefined;

export function createEmailOtpPostHandler(
  readMode: AuthRuntimeModeReader,
  createAuthAdapter: EmailOtpAuthAdapterFactory,
  readPolicy?: EmailOtpPolicyReader,
) {
  return (request: Request) => {
    const mode = readMode(request);
    return handleEmailOtpRequestForMode(
      request,
      mode,
      createAuthAdapter,
      readPolicy?.(request, mode),
    );
  };
}

export function createSessionGetHandler(
  readMode: AuthRuntimeModeReader,
  getClaims: SessionClaimsFactory,
) {
  return (request: Request) => handleSessionRequest(readMode(request), getClaims);
}

export function createLogoutPostHandler(
  readMode: AuthRuntimeModeReader,
  createAuthAdapter: LogoutAuthAdapterFactory,
  readAppOrigin?: AuthAppOriginReader,
) {
  return (request: Request) => {
    const mode = readMode(request);
    return handleLogoutRequestForMode(
      request,
      mode,
      createAuthAdapter,
      readAppOrigin?.(request, mode),
    );
  };
}

export function createAuthCallbackGetHandler(
  readMode: AuthRuntimeModeReader,
  exchange: AuthCodeExchange,
  decider?: AuthCallbackDecider,
  readAppOrigin?: AuthAppOriginReader,
) {
  return (request: Request) => {
    const mode = readMode(request);
    return handleAuthCallbackForMode(
      request,
      mode,
      exchange,
      decider,
      readAppOrigin?.(request, mode),
    );
  };
}
