import type {HTMLAttributes} from "react";

export function Card({className = "", ...props}: HTMLAttributes<HTMLDivElement>) {
  return <div className={`rounded-card bg-surface-elevated p-5 ${className}`} {...props} />;
}
