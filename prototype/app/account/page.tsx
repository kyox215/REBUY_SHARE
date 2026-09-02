import Link from "next/link";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { getAuthRuntimeModeForHost } from "@/lib/auth/runtime-mode";
import { resolveSessionStatus } from "@/lib/auth/session";
import { createClient } from "@/lib/supabase/server";
import AccountClient from "./AccountClient";
import styles from "./account.module.css";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const requestHeaders = await headers();
  const mode = getAuthRuntimeModeForHost(requestHeaders.get("host"));
  if (mode === "ui-only") {
    return <AccountClient mode="ui-only" />;
  }

  const session = await resolveSessionStatus({
    getClaims: async () => {
      const supabase = await createClient();
      return supabase.auth.getClaims();
    },
  });

  if (session.status === "anonymous") {
    redirect("/account/login?next=%2Faccount");
  }

  if (session.status === "error") {
    return (
      <main className={`${styles.page} theme-light`}>
        <section className={styles.authUnavailable} aria-labelledby="account-unavailable-title">
          <p className={styles.eyebrow}>账号中心</p>
          <h1 id="account-unavailable-title">暂时无法验证会话</h1>
          <p>请稍后重试，或返回登录页重新建立会话。</p>
          <Link href="/account/login?next=%2Faccount">返回登录</Link>
        </section>
      </main>
    );
  }

  return <AccountClient mode="authenticated" />;
}
