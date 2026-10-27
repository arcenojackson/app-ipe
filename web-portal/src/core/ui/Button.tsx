import type {ButtonHTMLAttributes} from "react";
import {Spinner} from "./Spinner";

type Variant = "primary" | "text";

export function Button({
  variant = "primary",
  className = "",
  loading = false,
  disabled,
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  /** Ação em andamento: mostra o spinner e bloqueia o clique. */
  loading?: boolean;
}) {
  const base =
    "inline-flex items-center justify-center gap-2 font-semibold transition disabled:cursor-not-allowed disabled:opacity-50";
  const styles =
    variant === "primary"
      ? "rounded-button bg-primary px-5 py-4 text-base text-on-primary hover:brightness-125"
      : "rounded-button px-4 py-2 text-on-surface hover:bg-white/10";
  return (
    <button
      className={`${base} ${styles} ${className}`}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading && <Spinner />}
      {children}
    </button>
  );
}
