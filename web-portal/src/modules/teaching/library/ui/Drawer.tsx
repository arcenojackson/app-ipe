"use client";

import {useEffect, type ReactNode} from "react";

// Painel lateral deslizante (à direita) com fundo escurecido; fecha com Esc ou
// clicando fora.
export function Drawer({title, onClose, children}: {title: string; onClose: () => void; children: ReactNode}) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-40 flex justify-end bg-black/60"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div role="dialog" aria-modal="true" aria-label={title} className="flex h-full w-full max-w-md flex-col bg-surface shadow-2xl">
        <div className="flex items-center justify-between border-b border-white/10 px-6 py-4">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button type="button" aria-label="Fechar" onClick={onClose} className="rounded-full px-3 py-1 text-white/70 hover:bg-white/10">
            ✕
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-5">{children}</div>
      </div>
    </div>
  );
}
