"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {formatBytes} from "../labels";
import {downloadUrl} from "../storageAccess";
import type {LibraryItem} from "../types";

// Baixa pelo SDK autenticado: a URL é obtida na hora do clique e abre em nova aba.
export function DownloadButton({item}: {item: LibraryItem}) {
  const [failed, setFailed] = useState(false);
  const path = item.storagePath;
  if (!path) return null;

  async function download(storagePath: string) {
    setFailed(false);
    try {
      const url = await downloadUrl(storagePath);
      window.open(url, "_blank", "noopener,noreferrer");
    } catch {
      setFailed(true);
    }
  }

  return (
    <div className="flex flex-col items-start gap-1">
      <Button type="button" variant="text" onClick={() => void download(path)}>
        Baixar
      </Button>
      {failed && (
        <p role="alert" className="text-sm text-error">
          Não foi possível baixar o arquivo.
        </p>
      )}
    </div>
  );
}

// Para tipos sem visualização: nome, tipo, tamanho e botão de baixar.
export function FileInfo({item}: {item: LibraryItem}) {
  return (
    <div className="space-y-2 rounded-card bg-white/5 p-4 text-sm">
      <p className="font-medium">{item.fileName ?? item.name}</p>
      <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-white/70">
        <dt>Tipo</dt>
        <dd>{item.contentType ?? "—"}</dd>
        <dt>Tamanho</dt>
        <dd>{item.size ? formatBytes(item.size) : "—"}</dd>
      </dl>
      <DownloadButton item={item} />
    </div>
  );
}
