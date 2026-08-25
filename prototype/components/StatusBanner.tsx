import { AlertCircle, CheckCircle2, Info, TriangleAlert } from "lucide-react";
import type { ReactNode } from "react";

type StatusBannerProps = {
  tone?: "info" | "success" | "warning" | "danger";
  children: ReactNode;
};

export default function StatusBanner({ tone = "info", children }: StatusBannerProps) {
  const Icon = tone === "success" ? CheckCircle2 : tone === "warning" ? TriangleAlert : tone === "danger" ? AlertCircle : Info;
  return (
    <div className={`status-banner status-banner--${tone}`} role={tone === "danger" ? "alert" : "status"}>
      <Icon size={18} aria-hidden="true" />
      <span>{children}</span>
    </div>
  );
}
