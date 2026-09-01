"use client";

import { ArrowLeft, Moon, Sun, X } from "lucide-react";
import Link from "next/link";
import type { FormEvent } from "react";
import { useEffect, useState } from "react";
import BrandMark from "@/components/BrandMark";
import {
  EMAIL_OTP_RESEND_COOLDOWN_MS,
  normalizeSyntheticEmail,
  type EmailOtpAction,
} from "@/lib/auth/email-otp";
import styles from "./login.module.css";

type LoginStep = "email" | "otp";
type Theme = "dark" | "light";
type BusyAction = EmailOtpAction | null;

type LoginPrototypeProps = {
  authStatus?: string;
  mode: "ui-only" | "local-auth";
};

type EmailOtpApiResponse =
  | { status: "otp_sent" | "verified" }
  | { status: "error"; code: string };

type EmailOtpApiResult =
  | { ok: true; status: "otp_sent" | "verified" }
  | { ok: false; code: string };

const errorMessages: Record<string, string> = {
  invalid_input: "请输入 @rebuy.test 本地测试邮箱和 6 位验证码。",
  invalid_request: "请输入有效的本地测试信息。",
  request_failed: "验证码暂时无法发送，请稍后再试。",
  verify_failed: "验证码无效或已过期，请重新获取。",
  resend_failed: "验证码暂时无法重发，请稍后再试。",
  rate_limited: "操作过于频繁，请稍后再试。",
  origin_not_allowed: "暂时无法完成本地登录，请稍后再试。",
  unsupported_media_type: "暂时无法完成本地登录，请稍后再试。",
  body_too_large: "暂时无法完成本地登录，请稍后再试。",
  server_error: "暂时无法完成本地登录，请稍后再试。",
  network_error: "暂时无法连接本地认证，请稍后再试。",
};

function messageForError(code: string) {
  return errorMessages[code] ?? errorMessages.server_error;
}

function isApiResponse(value: unknown): value is EmailOtpApiResponse {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const response = value as Record<string, unknown>;
  if (response.status === "otp_sent" || response.status === "verified") {
    return true;
  }

  return response.status === "error" && typeof response.code === "string";
}

async function postEmailOtp(payload: {
  action: EmailOtpAction;
  email: string;
  token?: string;
}): Promise<EmailOtpApiResult> {
  let response: Response;
  try {
    response = await fetch("/api/auth/email-otp", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch {
    return { ok: false, code: "network_error" };
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { ok: false, code: "server_error" };
  }

  if (!isApiResponse(body)) {
    return { ok: false, code: "server_error" };
  }

  if (response.ok && body.status !== "error") {
    return { ok: true, status: body.status };
  }

  return {
    ok: false,
    code: body.status === "error" ? body.code : "server_error",
  };
}

async function hasLocalSession() {
  try {
    const response = await fetch("/api/auth/session", {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    return response.ok;
  } catch {
    return false;
  }
}

function maskEmail(email: string) {
  const [localPart, domain] = email.split("@");
  return `${localPart?.slice(0, 1) ?? "*"}***@${domain ?? "rebuy.test"}`;
}

export default function LoginPrototype({ authStatus, mode }: LoginPrototypeProps) {
  const [theme, setTheme] = useState<Theme>("light");
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<LoginStep>("email");
  const [otp, setOtp] = useState("");
  const [emailError, setEmailError] = useState("");
  const [otpError, setOtpError] = useState("");
  const [errorMessage, setErrorMessage] = useState("");
  const [notice, setNotice] = useState("");
  const [busyAction, setBusyAction] = useState<BusyAction>(null);
  const [callbackMessage, setCallbackMessage] = useState(authStatus ?? "");
  const [resendCooldownMs, setResendCooldownMs] = useState(0);

  useEffect(() => {
    if (resendCooldownMs <= 0) {
      return;
    }

    const timeout = window.setTimeout(
      () => setResendCooldownMs(0),
      resendCooldownMs,
    );
    return () => window.clearTimeout(timeout);
  }, [resendCooldownMs]);

  const handleEmailSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (mode === "ui-only" || busyAction) {
      return;
    }

    setCallbackMessage("");
    setOtpError("");
    setErrorMessage("");
    setNotice("");
    const normalizedEmail = normalizeSyntheticEmail(email);

    if (!normalizedEmail) {
      setEmailError("请输入 @rebuy.test 本地测试邮箱。");
      return;
    }

    setEmail(normalizedEmail);
    setEmailError("");
    setOtp("");
    setBusyAction("request");

    const result = await postEmailOtp({ action: "request", email: normalizedEmail });
    setBusyAction(null);

    if (!result.ok) {
      setErrorMessage(messageForError(result.code));
      return;
    }

    setResendCooldownMs(EMAIL_OTP_RESEND_COOLDOWN_MS);
    setNotice("验证码已发送。");
    setStep("otp");
  };

  const handleOtpChange = (value: string) => {
    setOtp(value.replace(/\D/g, "").slice(0, 6));
    setOtpError("");
    setErrorMessage("");
    setNotice("");
    setCallbackMessage("");
  };

  const handleOtpSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (mode === "ui-only" || busyAction) {
      return;
    }

    setCallbackMessage("");
    setErrorMessage("");
    setNotice("");
    if (otp.length !== 6) {
      setOtpError("请输入 6 位验证码。");
      return;
    }

    setOtpError("");
    setBusyAction("verify");

    const result = await postEmailOtp({ action: "verify", email, token: otp });
    if (!result.ok) {
      setBusyAction(null);
      if (result.code === "verify_failed") {
        setOtpError(messageForError(result.code));
      } else {
        setErrorMessage(messageForError(result.code));
      }
      return;
    }

    if (!(await hasLocalSession())) {
      setBusyAction(null);
      setErrorMessage("登录未完成，请重新尝试。");
      return;
    }

    setBusyAction(null);
    setOtpError("");
    setNotice("本地会话已建立。");
    setStep("email");
  };

  const handleEditEmail = () => {
    if (busyAction) {
      return;
    }

    setStep("email");
    setOtp("");
    setEmailError("");
    setOtpError("");
    setErrorMessage("");
    setNotice("");
    setCallbackMessage("");
    setResendCooldownMs(0);
  };

  const handleResend = async () => {
    if (mode === "ui-only" || busyAction || !email || resendCooldownMs > 0) {
      return;
    }

    setCallbackMessage("");
    setOtpError("");
    setErrorMessage("");
    setNotice("");
    setBusyAction("resend");

    const result = await postEmailOtp({ action: "resend", email });
    setBusyAction(null);

    if (!result.ok) {
      if (result.code === "rate_limited") {
        setResendCooldownMs(EMAIL_OTP_RESEND_COOLDOWN_MS);
      }
      setErrorMessage(messageForError(result.code));
      return;
    }

    setOtp("");
    setResendCooldownMs(EMAIL_OTP_RESEND_COOLDOWN_MS);
    setNotice("验证码已重发。");
  };

  return (
    <main
      className={`${theme === "light" ? "theme-light" : "theme-dark"} ${styles.page}`}
      data-auth-mode={mode}
    >
      <div className={styles.frame}>
        <header className={styles.topbar}>
          <Link
            className={styles.backLink}
            href="/"
            aria-label="返回购物首页"
            title="返回购物首页"
          >
            <ArrowLeft aria-hidden="true" size={20} strokeWidth={2} />
          </Link>
          <span className={styles.brand}>
            <BrandMark />
          </span>
          <button
            className={styles.themeButton}
            type="button"
            onClick={() => setTheme((current) => (current === "dark" ? "light" : "dark"))}
            aria-label={theme === "dark" ? "切换浅色模式" : "切换深色模式"}
            title={theme === "dark" ? "切换浅色模式" : "切换深色模式"}
          >
            {theme === "dark" ? <Sun aria-hidden="true" size={19} /> : <Moon aria-hidden="true" size={19} />}
          </button>
        </header>

        <section className={styles.content} aria-labelledby="login-title">
          <div className={styles.intro}>
            <p className={styles.eyebrow}>账号入口</p>
            <h1 id="login-title">登录 Rebuy</h1>
            <p className={styles.status}>
              {mode === "ui-only" ? "当前为界面预览 · 登录功能暂未开放" : "本地测试认证 · 仅限合成邮箱"}
            </p>
          </div>

          <div className={styles.loginPanel}>
            {callbackMessage ? (
              <div className={styles.authStatus} role="alert">
                <span className={styles.authStatusText}>{callbackMessage}</span>
                <button
                  className={styles.dismissButton}
                  type="button"
                  onClick={() => setCallbackMessage("")}
                  aria-label="关闭提示"
                  title="关闭提示"
                >
                  <X aria-hidden="true" size={16} />
                </button>
              </div>
            ) : null}

            <div className={styles.providerStack} role="group" aria-label="第三方登录入口">
              <Link className={styles.appleButton} href="/account/provider/apple" title="查看 Apple 登录状态">
                使用 Apple 登录（待配置）
              </Link>
              <Link className={styles.googleButton} href="/account/provider/google" title="查看 Google 登录状态">
                使用 Google 登录（待配置）
              </Link>
            </div>

            {mode === "ui-only" ? (
              <div className={styles.previewNotice} role="status">
                <h2>账号登录暂未开放</h2>
                <p>当前为界面预览，邮箱验证码登录暂未开放。</p>
              </div>
            ) : step === "email" ? (
              <>
                <div className={styles.divider} aria-hidden="true">
                  <span />
                  <small>或使用邮箱</small>
                  <span />
                </div>

                <form className={styles.form} onSubmit={handleEmailSubmit} noValidate>
                  <div className={styles.fieldGroup}>
                    <label htmlFor="login-email">邮箱地址</label>
                    <input
                      id="login-email"
                      type="email"
                      inputMode="email"
                      autoComplete="email"
                      placeholder="name@rebuy.test"
                      value={email}
                      onChange={(event) => {
                        setEmail(event.target.value);
                        setEmailError("");
                        setOtpError("");
                        setErrorMessage("");
                        setNotice("");
                        setCallbackMessage("");
                      }}
                      aria-invalid={emailError ? "true" : "false"}
                      aria-describedby={emailError ? "email-error" : undefined}
                    />
                    {emailError ? (
                      <p className={styles.error} id="email-error" role="alert">
                        {emailError}
                      </p>
                    ) : null}
                  </div>
                  <button className={styles.primaryButton} type="submit" disabled={busyAction !== null} aria-busy={busyAction === "request"}>
                    {busyAction === "request" ? "发送中..." : "继续"}
                  </button>
                </form>
              </>
            ) : (
              <form className={styles.form} onSubmit={handleOtpSubmit}>
                <div className={styles.otpHeading}>
                  <h2>输入验证码</h2>
                  <p>验证码已发送至 {maskEmail(email)}</p>
                </div>

                <p className={styles.authMessage} role="status" aria-live="polite">
                  {notice}
                </p>

                <div className={styles.fieldGroup}>
                  <label htmlFor="login-otp">6 位验证码</label>
                  <input
                    id="login-otp"
                    className={styles.otpInput}
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    autoFocus
                    pattern="[0-9]*"
                    maxLength={6}
                    value={otp}
                    onChange={(event) => handleOtpChange(event.target.value)}
                    aria-invalid={otpError ? "true" : "false"}
                    aria-describedby={otpError ? "otp-error" : "otp-help"}
                  />
                  <p className={styles.fieldHelp} id="otp-help">
                    输入邮件中的 6 位数字。
                  </p>
                  {otpError ? (
                    <p className={styles.error} id="otp-error" role="alert">
                      {otpError}
                    </p>
                  ) : null}
                </div>

                {errorMessage ? (
                  <p className={styles.error} role="alert">
                    {errorMessage}
                  </p>
                ) : null}

                <button className={styles.primaryButton} type="submit" disabled={otp.length !== 6 || busyAction !== null} aria-busy={busyAction === "verify"}>
                  {busyAction === "verify" ? "验证中..." : "验证并登录"}
                </button>

                <div className={styles.otpActions}>
                  <button className={styles.editButton} type="button" onClick={handleEditEmail} disabled={busyAction !== null}>
                    修改邮箱
                  </button>
                  <button
                    className={styles.resendButton}
                    type="button"
                    onClick={handleResend}
                    disabled={busyAction !== null || resendCooldownMs > 0}
                  >
                    {busyAction === "resend"
                      ? "重发中..."
                      : resendCooldownMs > 0
                        ? "请稍候..."
                        : "重新发送"}
                  </button>
                </div>
              </form>
            )}

            {step === "email" && notice ? (
              <p className={styles.authMessage} role="status" aria-live="polite">
                {notice}
              </p>
            ) : null}
            {step === "email" && errorMessage ? (
              <p className={styles.error} role="alert">
                {errorMessage}
              </p>
            ) : null}
          </div>
        </section>

        <footer className={styles.footer}>
          <p>登录只确认身份，商家与批发资格仍需审核。</p>
          <Link className={styles.planLink} href="/account-mindmap">
            查看账号规划
          </Link>
        </footer>
      </div>
    </main>
  );
}
