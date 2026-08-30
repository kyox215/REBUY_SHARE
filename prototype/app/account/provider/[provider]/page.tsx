import { ArrowLeft, CircleHelp, Settings2 } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import BrandMark from "@/components/BrandMark";
import styles from "./provider.module.css";

const providers = {
  google: {
    label: "Google",
    description: "Google 账号连接",
  },
  apple: {
    label: "Apple",
    description: "Apple 账号连接",
  },
} as const;

export default async function ProviderPage({
  params,
}: {
  params: Promise<{ provider: string }>;
}) {
  const { provider } = await params;

  if (provider !== "google" && provider !== "apple") {
    notFound();
  }

  const providerCopy = providers[provider];

  return (
    <main className={styles.page}>
      <div className={styles.frame}>
        <header className={styles.topbar}>
          <Link className={styles.iconLink} href="/account/login" aria-label="返回邮箱登录" title="返回邮箱登录">
            <ArrowLeft aria-hidden="true" size={20} />
          </Link>
          <span className={styles.brand}>
            <BrandMark />
          </span>
          <span className={styles.topbarSpacer} aria-hidden="true" />
        </header>

        <section className={styles.content} aria-labelledby="provider-title">
          <div className={styles.providerIcon} aria-hidden="true">
            <Settings2 size={28} />
          </div>
          <p className={styles.eyebrow}>登录方式</p>
          <h1 id="provider-title">{providerCopy.label} 登录</h1>
          <p className={styles.lede}>{providerCopy.description}目前还没有完成凭证配置。</p>

          <div className={styles.statusBlock} role="status">
            <span className={styles.statusIcon} aria-hidden="true">
              <CircleHelp size={18} />
            </span>
            <div>
              <strong>等待凭证配置</strong>
              <p>当前不会跳转到 {providerCopy.label}，也不会创建账号。</p>
            </div>
          </div>

          <div className={styles.actions}>
            <Link className={styles.primaryAction} href="/account/login">
              返回邮箱 OTP 登录
            </Link>
            <Link className={styles.secondaryAction} href="/account">
              返回账号中心
            </Link>
          </div>

          <p className={styles.footerNote}>本地服务启动后，可以使用合成邮箱完成演示登录。</p>
        </section>
      </div>
    </main>
  );
}
