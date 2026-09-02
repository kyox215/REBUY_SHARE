import {
  handleAuthCallbackForMode,
  type AuthCallbackDecider,
} from "./callback-route";
import {
  handleEmailOtpRequestForMode,
  type EmailOtpAuthAdapterFactory,
} from "./email-otp-route";
import {
  handleLogoutRequestForMode,
  type LogoutAuthAdapterFactory,
} from "./logout";
import { handleSessionRequest, type SessionClaimsFactory } from "./session-route";
import type { AuthCodeExchange } from "./callback";
import type { AuthRuntimeModeReader } from "./runtime-mode-core";

export function createEmailOtpPostHandler(
  readMode: AuthRuntimeModeReader,
  createAuthAdapter: EmailOtpAuthAdapterFactory,
) {
  return (request: Request) =>
    handleEmailOtpRequestForMode(request, readMode(request), createAuthAdapter);
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
) {
  return (request: Request) =>
    handleLogoutRequestForMode(request, readMode(request), createAuthAdapter);
}

export function createAuthCallbackGetHandler(
  readMode: AuthRuntimeModeReader,
  exchange: AuthCodeExchange,
  decider?: AuthCallbackDecider,
) {
  return (request: Request) =>
    handleAuthCallbackForMode(request, readMode(request), exchange, decider);
}
