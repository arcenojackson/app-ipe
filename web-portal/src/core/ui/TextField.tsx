import type {InputHTMLAttributes} from "react";

export function TextField({
  label,
  id,
  className = "",
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {label: string; id: string}) {
  return (
    <label htmlFor={id} className="block text-sm text-white/70">
      {label}
      <input
        id={id}
        className={`mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface placeholder:text-white/40 focus:border-primary focus:outline-none ${className}`}
        {...props}
      />
    </label>
  );
}
