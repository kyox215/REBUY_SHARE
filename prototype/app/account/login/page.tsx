import type { Metadata } from "next";
import {
  AUTH_CALLBACK_ERROR_MESSAGES,
  isAuthCallbackErrorCode,
} from "@/lib/auth/callback";
import { normalizeSafeNext } from "@/lib/auth/redirect";
import LoginPrototype from "./LoginPrototype";

type LoginPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export const metadata: Metadata = {
  title: "注册或登录 Rebuy | 本地测试认证",
  description: "使用邮箱验证码注册或登录 Rebuy 本地测试账号。",
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const rawError = params.auth_error;
  const authStatus =
    isAuthCallbackErrorCode(rawError)
      ? AUTH_CALLBACK_ERROR_MESSAGES[rawError]
      : undefined;
  const rawNext = Array.isArray(params.next) ? params.next[0] : params.next;
  const nextPath = normalizeSafeNext(rawNext);

  return (
    <LoginPrototype
      key={`${authStatus ?? "none"}:${nextPath}`}
      authStatus={authStatus}
      nextPath={nextPath}
    />
  );
}
