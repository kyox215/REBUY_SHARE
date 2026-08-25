import type { Metadata } from "next";
import LoginPrototype from "./LoginPrototype";

export const metadata: Metadata = {
  title: "登录 Rebuy | 本地账号原型",
  description: "Rebuy 本地登录原型，未连接真实认证。",
};

export default function LoginPage() {
  return <LoginPrototype />;
}
