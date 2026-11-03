"use client";

import {useEffect, useId, useRef, type ReactNode} from "react";
import {Button} from "./Button";
import {GlassCard} from "./GlassCard";

interface Props {
  title: string;
  onClose: () => void;
  children: ReactNode;
}

/** Diálogo simples: fecha com o botão, Esc ou clicando fora; o foco entra no
 *  botão Fechar e volta para quem abriu. */
export function Modal({title, onClose, children}: Props) {
  const titleId = useId();
  const footerRef = useRef<HTMLDivElement>(null);
  const onCloseRef = useRef(onClose);
  useEffect(() => {
    onCloseRef.current = onClose;
  });

  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    footerRef.current?.querySelector<HTMLButtonElement>("button")?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onCloseRef.current();
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      opener?.focus?.();
    };
  }, []);

  return (
    <div
      data-testid="modal-backdrop"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
      onClick={onClose}
    >
      <GlassCard
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        className="max-h-[80vh] w-full max-w-md space-y-4 overflow-y-auto bg-surface"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 id={titleId} className="text-lg font-semibold">{title}</h2>
        {children}
        <div ref={footerRef}>
          <Button type="button" variant="text" onClick={onClose}>
            Fechar
          </Button>
        </div>
      </GlassCard>
    </div>
  );
}
