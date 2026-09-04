import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Rebuy | 买卖手机配件与二手设备",
  description: "Rebuy 连接零售客户、批发客户与经过审核的商家。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" data-scroll-behavior="smooth">
      <body>{children}</body>
    </html>
  );
}
