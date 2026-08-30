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
  title: "登录 Rebuy | 本地测试认证",
  description: "Rebuy 本地测试认证，仅限合成邮箱，不代表生产登录。",
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
