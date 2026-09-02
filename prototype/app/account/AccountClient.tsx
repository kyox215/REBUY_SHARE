"use client";

import { ArrowLeft, ChevronRight, CircleHelp, KeyRound, LogOut, Mail, Moon, ShieldCheck, Store, Sun, UserRound, UserPlus } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import BrandMark from "@/components/BrandMark";
import styles from "./account.module.css";

type Theme = "dark" | "light";

const authenticatedSecurityItems = [
  { href: "/account/login", icon: Mail, title: "邮箱验证码", description: "注册与登录流程已启用", status: "已启用", statusTone: "positive" },
  { href: "/account/provider/google", icon: KeyRound, title: "Google", description: "Google 登录页面预览", status: "待配置", statusTone: "neutral" },
  { href: "/account/provider/apple", icon: ShieldCheck, title: "Apple", description: "Apple 登录页面预览", status: "待配置", statusTone: "neutral" },
] as const;

const previewSecurityItems = [
  { href: "/account/login", icon: Mail, title: "邮箱登录", description: "当前为界面预览，登录功能暂未开放", status: "未开放", statusTone: "neutral" },
  { href: "/account/provider/google", icon: KeyRound, title: "Google", description: "Google 登录页面预览", status: "待配置", statusTone: "neutral" },
  { href: "/account/provider/apple", icon: ShieldCheck, title: "Apple", description: "Apple 登录页面预览", status: "待配置", statusTone: "neutral" },
] as const;

const authenticatedOrganizationItems = [
  { icon: Store, title: "当前身份", description: "零售客户", status: "已登录", statusTone: "positive" },
  { icon: UserRound, title: "店铺与组织", description: "关联关系将在后续业务阶段接入", status: "待接入", statusTone: "neutral" },
] as const;

const previewOrganizationItems = [
  { icon: Store, title: "当前身份", description: "本地演示身份 · 预览", status: "预览", statusTone: "neutral" },
  { icon: UserRound, title: "店铺与组织", description: "登录后可管理关联关系", status: "未连接", statusTone: "neutral" },
] as const;

function StatusPill({ tone, children }: { tone: "positive" | "neutral"; children: string }) {
  return <span className={`${styles.statusPill} ${tone === "positive" ? styles.statusPillPositive : ""}`}>{children}</span>;
}

export default function AccountClient({
  mode,
}: {
  mode: "authenticated" | "ui-only";
}) {
  const router = useRouter();
  const authenticated = mode === "authenticated";
  const securityItems = authenticated
    ? authenticatedSecurityItems
    : previewSecurityItems;
  const organizationItems = authenticated
    ? authenticatedOrganizationItems
    : previewOrganizationItems;
  const [theme, setTheme] = useState<Theme>("light");
  const [signingOut, setSigningOut] = useState(false);
  const [signOutError, setSignOutError] = useState("");

  const handleSignOut = async () => {
    if (!authenticated || signingOut) return;
    setSigningOut(true);
    setSignOutError("");

    try {
      const response = await fetch("/api/auth/logout", {
        method: "POST",
        headers: { Accept: "application/json" },
      });
      if (!response.ok) {
        setSignOutError("暂时无法退出，请稍后再试。");
        setSigningOut(false);
        return;
      }

      router.replace("/account/login");
      router.refresh();
    } catch {
      setSignOutError("暂时无法退出，请稍后再试。");
      setSigningOut(false);
    }
  };

  return (
    <main className={`${styles.page} ${theme === "light" ? "theme-light" : ""}`}>
      <div className={styles.frame}>
        <header className={styles.topbar}>
          <Link className={styles.iconLink} href="/" aria-label="返回购物首页" title="返回购物首页"><ArrowLeft aria-hidden="true" size={20} /></Link>
          <span className={styles.brand}><BrandMark /></span>
          <button className={styles.iconButton} type="button" onClick={() => setTheme((current) => (current === "dark" ? "light" : "dark"))} aria-label={theme === "dark" ? "切换浅色模式" : "切换深色模式"} title={theme === "dark" ? "切换浅色模式" : "切换深色模式"}>
            {theme === "dark" ? <Sun aria-hidden="true" size={19} /> : <Moon aria-hidden="true" size={19} />}
          </button>
        </header>

        <section className={styles.content} aria-labelledby="account-title">
          <div className={styles.pageHeading}>
            <div><p className={styles.eyebrow}>账号中心</p><h1 id="account-title">你的 Rebuy 账号</h1><p className={styles.headingCopy}>管理登录方式、组织关系和邀请。</p></div>
            <div className={styles.profileMark} aria-hidden="true"><UserRound size={24} /></div>
          </div>

          <div className={styles.previewStatus} role="status"><span className={styles.previewStatusDot} aria-hidden="true" /><span><strong>{authenticated ? "会话已验证" : "界面预览"}</strong><small>{authenticated ? "本地测试账号" : "未连接真实账号"}</small></span></div>

          <div className={styles.groups}>
            <section className={styles.group} aria-labelledby="security-title">
              <div className={styles.groupHeading}><h2 id="security-title">登录与安全</h2><span>3 项</span></div>
              <div className={styles.rowList}>
                {securityItems.map(({ href, icon: Icon, title, description, status, statusTone }) => (
                  <Link className={styles.accountRow} href={href} key={href}>
                    <span className={styles.rowIcon} aria-hidden="true"><Icon size={19} /></span>
                    <span className={styles.rowCopy}><strong>{title}</strong><small>{description}</small></span>
                    <span className={styles.rowMeta}><StatusPill tone={statusTone}>{status}</StatusPill><ChevronRight aria-hidden="true" size={18} /></span>
                  </Link>
                ))}
              </div>
            </section>

            <section className={styles.group} aria-labelledby="organization-title">
              <div className={styles.groupHeading}><h2 id="organization-title">组织与店铺</h2><span>{authenticated ? "当前状态" : "本地状态"}</span></div>
              <div className={styles.rowList}>
                {organizationItems.map(({ icon: Icon, title, description, status, statusTone }) => (
                  <div className={styles.accountRow} key={title}>
                    <span className={styles.rowIcon} aria-hidden="true"><Icon size={19} /></span>
                    <span className={styles.rowCopy}><strong>{title}</strong><small>{description}</small></span>
                    <span className={styles.rowMeta}><StatusPill tone={statusTone}>{status}</StatusPill></span>
                  </div>
                ))}
              </div>
            </section>

            <section className={styles.group} aria-labelledby="invites-title">
              <div className={styles.groupHeading}><h2 id="invites-title">邀请</h2><span>团队协作</span></div>
              <div className={styles.rowList}>
                <div className={styles.accountRow}>
                  <span className={styles.rowIcon} aria-hidden="true"><UserPlus size={19} /></span>
                  <span className={styles.rowCopy}><strong>待处理邀请</strong><small>组织邀请将在权限阶段接入</small></span>
                  <span className={styles.rowMeta}><StatusPill tone="neutral">暂无</StatusPill></span>
                </div>
              </div>
            </section>
          </div>

          {authenticated ? (
            <>
              <button className={styles.logoutButton} type="button" onClick={handleSignOut} disabled={signingOut} aria-busy={signingOut}>
                <LogOut aria-hidden="true" size={17} />{signingOut ? "正在退出..." : "退出当前账号"}
              </button>
              {signOutError ? <p className={styles.signOutError} role="alert">{signOutError}</p> : null}
            </>
          ) : null}

          <div className={styles.note}><CircleHelp aria-hidden="true" size={17} /><p>{authenticated ? "邮箱验证码已建立真实本地会话；第三方登录和组织业务仍按后续阶段接入。" : "这是界面预览页面。账号连接和第三方凭证尚未启用。"}</p></div>
        </section>
      </div>
    </main>
  );
}
