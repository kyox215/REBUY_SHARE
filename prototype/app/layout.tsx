import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Rebuy | local client prototype",
  description: "Rebuy is a replaceable working name for a local buyer-client prototype.",
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
