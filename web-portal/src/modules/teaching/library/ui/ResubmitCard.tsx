"use client";

import {useRef, useState, type DragEvent} from "react";
import {Button} from "@/core/ui/Button";
import {formatBytes} from "../labels";

// Reenvio de arquivo devolvido, em destaque para o autor. Nada é enviado ao
// escolher o arquivo: só ao clicar em "Reenviar". Se falhar, o arquivo escolhido
// fica para tentar de novo.
export function ResubmitCard({
  busy,
  progress,
  onResubmit,
}: {
  busy: boolean;
  progress: number | null;
  onResubmit: (file: File) => Promise<void>;
}) {
  const [file, setFile] = useState<File | null>(null);
  const input = useRef<HTMLInputElement>(null);

  function choose(files: File[]) {
    if (files[0]) setFile(files[0]);
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    if (!busy) choose(Array.from(event.dataTransfer?.files ?? []));
  }

  async function submit() {
    if (!file || busy) return;
    try {
      await onResubmit(file);
      setFile(null);
    } catch {
      // A tela mostra o motivo; o arquivo continua escolhido.
    }
  }

  return (
    <section aria-label="Reenviar arquivo corrigido" className="space-y-3 rounded-card border border-secondary/40 bg-secondary/10 p-4">
      <h3 className="font-semibold">Reenviar arquivo corrigido</h3>
      <div
        data-testid="resubmit-drop"
        onDragOver={(e) => e.preventDefault()}
        onDrop={onDrop}
        className="rounded-card border border-dashed border-white/25 p-4 text-center text-sm text-white/70"
      >
        Arraste o arquivo corrigido aqui ou{" "}
        <Button type="button" variant="text" className="px-1 py-0" disabled={busy} onClick={() => input.current?.click()}>
          Escolher arquivo
        </Button>
        <input
          ref={input}
          type="file"
          aria-label="Escolher novo arquivo"
          disabled={busy}
          className="hidden"
          onChange={(event) => {
            choose(Array.from(event.target.files ?? []));
            event.target.value = "";
          }}
        />
      </div>
      {file && (
        <div className="flex items-center justify-between gap-2 rounded-card bg-surface-elevated px-3 py-2 text-sm">
          <span className="truncate">{file.name}</span>
          <span className="text-white/60">{formatBytes(file.size)}</span>
          <button
            type="button"
            aria-label={`Remover ${file.name}`}
            disabled={busy}
            onClick={() => setFile(null)}
            className="rounded-full px-2 text-white/60 hover:bg-white/10"
          >
            ✕
          </button>
        </div>
      )}
      {progress !== null && <progress className="w-full" value={progress} max={1} />}
      <Button type="button" className="w-full py-3" disabled={!file || busy} onClick={() => void submit()}>
        {busy ? "Reenviando…" : "Reenviar"}
      </Button>
      {!file && <p className="text-sm text-white/60">Falta: o arquivo corrigido</p>}
    </section>
  );
}
