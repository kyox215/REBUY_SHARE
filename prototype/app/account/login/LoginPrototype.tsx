"use client";

import { ArrowLeft, Moon, Sun } from "lucide-react";
import Link from "next/link";
import type { FormEvent } from "react";
import { useState } from "react";
import BrandMark from "@/components/BrandMark";
import styles from "./login.module.css";

type LoginStep = "email" | "otp";
type Theme = "dark" | "light";

type LoginPrototypeProps = {
  authStatus?: string;
};

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default function LoginPrototype({ authStatus }: LoginPrototypeProps) {
  const [theme, setTheme] = useState<Theme>("light");
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<LoginStep>("email");
  const [otp, setOtp] = useState("");
  const [emailError, setEmailError] = useState("");
  const [providerStatus, setProviderStatus] = useState("");
  const [completionStatus, setCompletionStatus] = useState("");

  const handleProviderClick = () => {
    setProviderStatus("等待 A1 测试环境");
  };

  const handleEmailSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const normalizedEmail = email.trim();

    if (!emailPattern.test(normalizedEmail)) {
      setEmailError("请输入有效的邮箱地址。");
      return;
    }

    setEmail(normalizedEmail);
    setEmailError("");
    setOtp("");
    setCompletionStatus("");
    setStep("otp");
  };

  const handleOtpChange = (value: string) => {
    setOtp(value.replace(/\D/g, "").slice(0, 6));
    setCompletionStatus("");
  };

  const handleOtpSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (otp.length === 6) {
      setCompletionStatus("界面流程完成，未建立账号或会话");
    }
  };

  const handleEditEmail = () => {
    setStep("email");
    setOtp("");
    setCompletionStatus("");
  };

  return (
    <main className={`${theme === "light" ? "theme-light" : "theme-dark"} ${styles.page}`}>
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
            <p className={styles.status}>本地原型 · 未连接认证</p>
          </div>

          <div className={styles.loginPanel}>
            {authStatus ? (
              <p className={styles.authStatus} role="alert">
                {authStatus}
              </p>
            ) : null}

            {step === "email" ? (
              <>
                <div className={styles.providerStack} role="group" aria-label="第三方登录入口">
                  <button className={styles.appleButton} type="button" onClick={handleProviderClick}>
                    使用 Apple 登录
                  </button>
                  <button className={styles.googleButton} type="button" onClick={handleProviderClick}>
                    使用 Google 登录
                  </button>
                </div>

                <div className={styles.providerStatus} role="status" aria-live="polite">
                  {providerStatus}
                </div>

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
                      autoComplete="off"
                      placeholder="name@example.com"
                      value={email}
                      onChange={(event) => {
                        setEmail(event.target.value);
                        if (emailError) {
                          setEmailError("");
                        }
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
                  <button className={styles.primaryButton} type="submit">
                    继续
                  </button>
                </form>
              </>
            ) : (
              <form className={styles.form} onSubmit={handleOtpSubmit}>
                <div className={styles.otpHeading}>
                  <h2>输入验证码</h2>
                  <p>已输入邮箱：{email}</p>
                </div>

                <p className={styles.demoNotice} role="status">
                  界面演示，未发送邮件。
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
                    aria-describedby="otp-help"
                  />
                  <p className={styles.fieldHelp} id="otp-help">
                    仅用于检查本地界面状态。
                  </p>
                </div>

                <button className={styles.primaryButton} type="submit" disabled={otp.length !== 6}>
                  完成演示
                </button>

                <button className={styles.editButton} type="button" onClick={handleEditEmail}>
                  返回修改邮箱
                </button>

                <p className={styles.completionStatus} role="status" aria-live="polite">
                  {completionStatus}
                </p>
              </form>
            )}
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
