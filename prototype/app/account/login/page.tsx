import type { Metadata } from "next";
import {
  AUTH_CALLBACK_ERROR_MESSAGES,
  isAuthCallbackErrorCode,
} from "@/lib/auth/callback";
import LoginPrototype from "./LoginPrototype";

type LoginPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export const metadata: Metadata = {
  title: "登录 Rebuy | 本地账号原型",
  description: "Rebuy 本地登录原型，未连接真实认证。",
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const rawError = params.auth_error;
  const authStatus =
    isAuthCallbackErrorCode(rawError)
      ? AUTH_CALLBACK_ERROR_MESSAGES[rawError]
      : undefined;

  return <LoginPrototype authStatus={authStatus} />;
}
