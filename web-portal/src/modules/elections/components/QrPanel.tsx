"use client";

import {useState} from "react";
import {QRCodeSVG} from "qrcode.react";
import {Button} from "@/core/ui/Button";

type CopyState = "idle" | "copied" | "failed";

/** Copia pela API moderna e, sem ela (contexto sem permissão, WebView), pelo
 *  `execCommand`. Devolve se alguma das duas funcionou. */
async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    area.setSelectionRange(0, text.length);
    try {
      return document.execCommand("copy");
    } catch {
      return false;
    } finally {
      document.body.removeChild(area);
    }
  }
}

/** QR e link da votação, próprios para projetar. Só renderiza no navegador. */
export function QrPanel({electionId}: {electionId: string}) {
  const [copy, setCopy] = useState<CopyState>("idle");
  const origin = typeof window === "undefined" ? "" : window.location.origin;
  const link = `${origin}/votar/${electionId}`;

  return (
    <div className="flex flex-col items-center gap-3">
      <div className="rounded-card bg-white p-4">
        <QRCodeSVG value={link} size={224} title="QR da votação" />
      </div>
      <p className="break-all text-center text-sm text-white/70 select-all">
        {link}
      </p>
      <Button
        type="button"
        variant="text"
        onClick={async () => {
          setCopy((await copyText(link)) ? "copied" : "failed");
          setTimeout(() => setCopy("idle"), 3000);
        }}
      >
        {copy === "copied" ? "Link copiado" : "Copiar link"}
      </Button>
      {copy === "failed" && (
        <p role="status" className="text-center text-sm text-white/70">
          Não foi possível copiar. Toque e segure o link acima para copiar.
        </p>
      )}
    </div>
  );
}
