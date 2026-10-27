"use client";

import {useEffect, useRef, useState, type ReactNode} from "react";
import {Icon} from "@/core/ui/icons";

export const menuItemClass = "block w-full rounded-lg px-3 py-2 text-left text-sm hover:bg-white/10";

export function MenuHeading({children}: {children: ReactNode}) {
  return <p className="mt-1 border-t border-white/10 px-3 pb-1 pt-2 text-[11px] uppercase tracking-wider text-white/60">{children}</p>;
}

// Menu "⋯": agrupa ações secundárias. Fecha ao clicar fora, com Esc ou depois
// de escolher um item.
export function ActionMenu({label = "Mais ações", children}: {label?: string; children: ReactNode}) {
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointer = (event: MouseEvent) => {
      if (!box.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={box} className="relative">
      <button
        type="button"
        aria-label={label}
        aria-expanded={open}
        onClick={() => setOpen(!open)}
        className="rounded-full p-1.5 text-white/60 hover:bg-white/10 hover:text-white"
      >
        <Icon name="more" className="h-5 w-5" />
      </button>
      {open && (
        <div role="menu" onClick={() => setOpen(false)} className="absolute right-0 z-10 mt-1 w-48 rounded-card bg-surface-elevated p-1.5 shadow-xl ring-1 ring-white/10">
          {children}
        </div>
      )}
    </div>
  );
}
