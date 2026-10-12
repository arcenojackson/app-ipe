import type {HTMLAttributes} from "react";

export function GlassCard({className = "", ...props}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-glass border border-white/[0.08] bg-gradient-to-br from-white/[0.12] to-white/[0.04] p-5 backdrop-blur-[20px] ${className}`}
      {...props}
    />
  );
}
