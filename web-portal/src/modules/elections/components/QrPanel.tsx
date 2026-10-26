"use client";

import {QRCodeSVG} from "qrcode.react";
import {Button} from "@/core/ui/Button";

/** QR e link da votação, próprios para projetar. Só renderiza no navegador. */
export function QrPanel({electionId}: {electionId: string}) {
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  const link = `${origin}/votar/${electionId}`;

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="rounded-card bg-white p-4">
        <QRCodeSVG value={link} size={224} title="QR da votação" />
      </div>
      <p className="break-all text-center text-sm text-white/70">{link}</p>
      <Button
        type="button"
        variant="text"
        onClick={() => void navigator.clipboard?.writeText(link)}
      >
        Copiar link
      </Button>
    </div>
  );
}
