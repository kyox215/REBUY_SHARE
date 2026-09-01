import type { Metadata } from "next";
import { headers } from "next/headers";
import {
  AUTH_CALLBACK_ERROR_MESSAGES,
  isAuthCallbackErrorCode,
} from "@/lib/auth/callback";
import { getAuthRuntimeModeForHost } from "@/lib/auth/runtime-mode";
import LoginPrototype from "./LoginPrototype";

type LoginPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export const metadata: Metadata = {
  title: "登录 Rebuy | 账号入口与界面预览",
  description: "Rebuy 账号入口，界面预览与本地测试边界。",
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const rawError = params.auth_error;
  const authStatus =
    isAuthCallbackErrorCode(rawError)
      ? AUTH_CALLBACK_ERROR_MESSAGES[rawError]
      : undefined;
  const requestHeaders = await headers();
  const mode = getAuthRuntimeModeForHost(requestHeaders.get("host"));

  return <LoginPrototype key={`${mode}:${authStatus ?? "none"}`} authStatus={authStatus} mode={mode} />;
}
