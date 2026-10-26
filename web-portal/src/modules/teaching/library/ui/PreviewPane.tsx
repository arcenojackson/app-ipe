"use client";

import {useEffect, useRef, useState} from "react";
import {renderDocx} from "../docxRender";
import {renderPdf} from "../pdfRender";
import {MAX_INLINE_PREVIEW_BYTES, previewKind} from "../preview";
import type {LibraryItem} from "../types";
import {useFileBytes} from "../useFileBytes";
import {DownloadButton, FileInfo} from "./FileInfo";

const UNAVAILABLE = "Não foi possível exibir o arquivo. Baixe para abri-lo.";

// Visualização do arquivo no navegador: PDF, imagens e DOCX. Os demais tipos
// (e arquivos muito grandes) mostram só as informações e o botão de baixar.
export function PreviewPane({item}: {item: LibraryItem}) {
  const kind = previewKind(item.contentType, item.fileName);
  const tooBig = (item.size ?? 0) > MAX_INLINE_PREVIEW_BYTES;
  const inline = item.type === "file" && kind !== "other" && !tooBig;
  const {bytes, loading, error} = useFileBytes(item.storagePath, inline);

  const container = useRef<HTMLDivElement>(null);
  const [failedBytes, setFailedBytes] = useState<ArrayBuffer | null>(null);
  const [image, setImage] = useState<{bytes: ArrayBuffer; url: string} | null>(null);

  useEffect(() => {
    const target = container.current;
    if (!bytes || !target || (kind !== "pdf" && kind !== "docx")) return;
    let cancelled = false;
    let cleanup: (() => void) | undefined;
    const render = kind === "pdf" ? renderPdf : renderDocx;
    render(target, bytes)
      .then((stop) => {
        if (cancelled) stop();
        else cleanup = stop;
      })
      .catch(() => {
        if (!cancelled) setFailedBytes(bytes);
      });
    return () => {
      cancelled = true;
      cleanup?.();
    };
  }, [bytes, kind]);

  useEffect(() => {
    if (!bytes || kind !== "image") return;
    let active = true;
    const url = URL.createObjectURL(new Blob([bytes], {type: item.contentType}));
    queueMicrotask(() => active && setImage({bytes, url}));
    return () => {
      active = false;
      URL.revokeObjectURL(url);
    };
  }, [bytes, kind, item.contentType]);

  if (item.type !== "file") return null;

  if (!inline) {
    return (
      <div className="space-y-2">
        {tooBig && <p className="text-sm text-white/70">Arquivo grande demais para visualizar aqui.</p>}
        <FileInfo item={item} />
      </div>
    );
  }

  if (error || (bytes && failedBytes === bytes)) {
    return (
      <div className="space-y-2">
        <p role="status" className="text-sm text-white/70">{UNAVAILABLE}</p>
        <FileInfo item={item} />
      </div>
    );
  }

  return (
    <div className="space-y-2">
      {loading && <p className="text-white/70">Carregando visualização…</p>}
      {(kind === "pdf" || kind === "docx") && (
        <div
          ref={container}
          aria-label={`Visualização de ${item.name}`}
          className={`max-h-[60vh] overflow-auto rounded-card ${kind === "docx" ? "bg-white text-black" : ""}`}
        />
      )}
      {kind === "image" && image && image.bytes === bytes && (
        // eslint-disable-next-line @next/next/no-img-element -- blob local lido pelo SDK, fora do otimizador do Next
        <img alt={item.name} src={image.url} className="max-h-[60vh] rounded-card" />
      )}
      <DownloadButton item={item} />
    </div>
  );
}
