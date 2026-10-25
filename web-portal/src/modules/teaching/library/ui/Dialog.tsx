"use client";

import {useEffect, type ReactNode} from "react";

export function Dialog({
  title,
  onClose,
  children,
  wide = false,
  hideTitle = false,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
  hideTitle?: boolean;
}) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div role="dialog" aria-modal="true" aria-label={title} className={`w-full rounded-dialog bg-surface p-6 shadow-xl ${wide ? "max-h-[90vh] max-w-4xl overflow-y-auto" : "max-w-md"}`}>
        <h2 className={hideTitle ? "sr-only" : "mb-4 text-lg font-semibold"}>{title}</h2>
        {children}
      </div>
    </div>
  );
}
