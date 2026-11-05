import type { ReactNode } from "react";

export type BannerTone = "error" | "warning" | "success" | "info";

const styles: Record<BannerTone, { box: string; icon: string; glyph: string }> = {
  error: { box: "border-red-300 bg-red-50 text-red-800", icon: "bg-red-500", glyph: "!" },
  warning: { box: "border-amber-300 bg-amber-50 text-amber-900", icon: "bg-amber-500", glyph: "!" },
  success: { box: "border-emerald-300 bg-emerald-50 text-emerald-800", icon: "bg-emerald-500", glyph: "✓" },
  info: { box: "border-blue-300 bg-blue-50 text-blue-900", icon: "bg-blue-500", glyph: "i" },
};

interface BannerProps {
  tone: BannerTone;
  title: string;
  children?: ReactNode;
  onDismiss?: () => void;
}

export function Banner({ tone, title, children, onDismiss }: BannerProps) {
  const s = styles[tone];
  return (
    <div
      role={tone === "error" || tone === "warning" ? "alert" : "status"}
      className={`flex items-start gap-3 rounded-lg border px-4 py-3 ${s.box}`}
    >
      <span
        aria-hidden
        className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-xs font-bold text-white ${s.icon}`}
      >
        {s.glyph}
      </span>
      <div className="min-w-0 flex-1">
        <p className="font-semibold">{title}</p>
        {children && <div className="mt-0.5 text-sm">{children}</div>}
      </div>
      {onDismiss && (
        <button
          type="button"
          onClick={onDismiss}
          className="rounded px-1 text-lg leading-none opacity-60 hover:opacity-100"
          aria-label="Dismiss"
        >
          ×
        </button>
      )}
    </div>
  );
}
