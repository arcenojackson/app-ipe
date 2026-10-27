"use client";

import {useRef, useState, type DragEvent} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {validateName, validateUrl} from "../files";
import {formatBytes} from "../labels";
import {createLink, uploadFile} from "../mutations";
import {EMPTY_TAGS, type ItemTags} from "../tags";
import {UploadError} from "../uploadFlow";
import {useTags} from "../useTags";
import {Drawer} from "./Drawer";
import {TagPicker} from "./TagPicker";

type Status = "pending" | "uploading" | "done" | "error";

interface FileEntry {
  key: number;
  file: File;
  status: Status;
  progress: number;
  message?: string;
}

const DISCARD = "Descartar o que foi preenchido?";

// Painel "Enviar material". Nada é enviado até o botão "Enviar": arquivos, link,
// nome e tags podem ser preenchidos em qualquer ordem.
export function UploadDrawer({
  uid,
  onClose,
  onSubmitted,
}: {
  uid: string;
  onClose: () => void;
  onSubmitted?: () => void;
}) {
  const {tags: tagList, error: tagsError} = useTags();
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [linkOpen, setLinkOpen] = useState(false);
  const [url, setUrl] = useState("");
  const [description, setDescription] = useState("");
  const [name, setName] = useState("");
  const [tags, setTags] = useState<ItemTags>(EMPTY_TAGS);
  const [linkStatus, setLinkStatus] = useState<Status>("pending");
  const [linkMessage, setLinkMessage] = useState<string>();
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const [success, setSuccess] = useState(false);
  const counter = useRef(0);
  const input = useRef<HTMLInputElement>(null);

  const missing: string[] = [];
  if (files.length === 0 && !linkOpen) missing.push("arquivo ou link");
  if (tags.typeTags.length === 0) missing.push("tag de tipo");
  if (tags.subjectTags.length === 0) missing.push("tag de assunto");
  if (tags.ageTags.length === 0) missing.push("tag de faixa etária");
  if (linkOpen && validateName(name)) missing.push("nome do link");
  if (linkOpen && validateUrl(url)) missing.push("endereço do link (http:// ou https://)");

  const dirty =
    files.length > 0 || linkOpen || name !== "" || url !== "" || description !== "" ||
    tags.typeTags.length + tags.subjectTags.length + tags.ageTags.length > 0;

  function requestClose() {
    if (busy) return;
    if (dirty && !window.confirm(DISCARD)) return;
    onClose();
  }

  function addFiles(list: File[]) {
    if (list.length === 0) return;
    setSuccess(false);
    setFiles((current) => [
      ...current,
      ...list.map((file) => ({key: counter.current++, file, status: "pending" as Status, progress: 0})),
    ]);
  }

  function patch(key: number, changes: Partial<FileEntry>) {
    setFiles((list) => list.map((e) => (e.key === key ? {...e, ...changes} : e)));
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    addFiles(Array.from(event.dataTransfer?.files ?? []));
  }

  async function submit() {
    if (busy || missing.length > 0) return;
    setBusy(true);
    setFailed(false);
    setSuccess(false);
    let anyFailed = false;
    const singleName = files.length === 1 && !linkOpen && name.trim() ? name.trim() : undefined;
    for (const entry of files) {
      if (entry.status === "done") continue;
      patch(entry.key, {status: "uploading", progress: 0, message: undefined});
      try {
        await uploadFile(uid, entry.file, {
          tags,
          name: singleName,
          onProgress: (progress) => patch(entry.key, {progress}),
        });
        patch(entry.key, {status: "done", progress: 1});
        onSubmitted?.();
      } catch (error) {
        anyFailed = true;
        patch(entry.key, {
          status: "error",
          message: error instanceof UploadError ?
            error.message :
            "Não foi possível enviar o arquivo. Tente novamente.",
        });
      }
    }
    if (linkOpen && linkStatus !== "done") {
      setLinkStatus("uploading");
      setLinkMessage(undefined);
      try {
        await createLink(uid, {name: name.trim(), url: url.trim(), description, tags});
        setLinkStatus("done");
        onSubmitted?.();
      } catch {
        anyFailed = true;
        setLinkStatus("error");
        setLinkMessage("Não foi possível adicionar o link. Tente novamente.");
      }
    }
    setBusy(false);
    if (anyFailed) {
      setFailed(true);
      return;
    }
    setFiles([]);
    setLinkOpen(false);
    setLinkStatus("pending");
    setUrl("");
    setDescription("");
    setName("");
    setTags(EMPTY_TAGS);
    setSuccess(true);
  }

  const footer = (
    <div className="space-y-2">
      {failed && (
        <p role="alert" className="text-sm text-error">
          Alguns itens não foram enviados. O que você preencheu foi mantido: toque em Enviar para tentar de novo.
        </p>
      )}
      {success && <p role="status" className="text-sm text-secondary">Enviado! O material foi para a revisão.</p>}
      {missing.length > 0 && (
        <p id="upload-missing" className="text-sm text-white/70">Falta: {missing.join(", ")}</p>
      )}
      <Button
        type="button"
        className="w-full py-3"
        disabled={busy || missing.length > 0}
        aria-describedby={missing.length > 0 ? "upload-missing" : undefined}
        onClick={() => void submit()}
      >
        {busy ? "Enviando…" : "Enviar"}
      </Button>
    </div>
  );

  return (
    <Drawer title="Enviar material" onClose={requestClose} footer={footer}>
      <div className="space-y-4">
        <TextField
          id="upload-name"
          label={linkOpen ? "Nome" : "Nome (opcional; vale para um único arquivo)"}
          value={name}
          maxLength={120}
          onChange={(e) => setName(e.target.value)}
        />
        <div
          data-testid="drop-zone"
          onDragOver={(e) => e.preventDefault()}
          onDrop={onDrop}
          className="rounded-card border border-dashed border-white/20 p-4 text-center text-sm text-white/70"
        >
          Arraste arquivos aqui (qualquer tipo, até 100 MB) ou{" "}
          <Button type="button" variant="text" className="px-1 py-0" onClick={() => input.current?.click()}>
            Escolher arquivos
          </Button>
          <input
            ref={input}
            type="file"
            multiple
            aria-label="Escolher arquivos"
            className="hidden"
            onChange={(e) => {
              addFiles(Array.from(e.target.files ?? []));
              e.target.value = "";
            }}
          />
        </div>
        {files.length > 0 && (
          <ul className="space-y-1">
            {files.map((entry) => (
              <li key={entry.key} className="rounded-card bg-surface-elevated px-3 py-2 text-sm">
                <div className="flex items-center justify-between gap-2">
                  <span className="truncate">{entry.file.name}</span>
                  <span className={entry.status === "error" ? "text-error" : "text-white/70"}>
                    {entry.status === "pending" && formatBytes(entry.file.size)}
                    {entry.status === "uploading" && `${Math.round(entry.progress * 100)}%`}
                    {entry.status === "done" && "Enviado"}
                    {entry.status === "error" && entry.message}
                  </span>
                  {entry.status !== "done" && entry.status !== "uploading" && (
                    <button
                      type="button"
                      aria-label={`Remover ${entry.file.name}`}
                      onClick={() => setFiles((list) => list.filter((e) => e.key !== entry.key))}
                      className="rounded-full px-2 text-white/60 hover:bg-white/10"
                    >
                      ✕
                    </button>
                  )}
                </div>
                {entry.status === "uploading" && <progress className="mt-1 w-full" value={entry.progress} max={1} />}
              </li>
            ))}
          </ul>
        )}
        {linkOpen ? (
          <div className="space-y-3 rounded-card bg-surface-elevated p-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold">Link</span>
              {linkStatus !== "done" && (
                <button
                  type="button"
                  aria-label="Remover link"
                  disabled={busy}
                  onClick={() => {
                    setLinkOpen(false);
                    setLinkStatus("pending");
                  }}
                  className="rounded-full px-2 text-white/60 hover:bg-white/10"
                >
                  ✕
                </button>
              )}
            </div>
            <TextField id="upload-url" label="Endereço (URL)" value={url} onChange={(e) => setUrl(e.target.value)} />
            <TextField
              id="upload-description"
              label="Descrição (opcional)"
              value={description}
              maxLength={1000}
              onChange={(e) => setDescription(e.target.value)}
            />
            {linkStatus === "done" && <p className="text-sm text-white/70">Enviado</p>}
            {linkStatus === "error" && <p className="text-sm text-error">{linkMessage}</p>}
          </div>
        ) : (
          <Button type="button" variant="text" className="px-0" onClick={() => setLinkOpen(true)}>
            Adicionar link
          </Button>
        )}
        <TagPicker tags={tagList ?? []} value={tags} onChange={setTags} loadError={tagsError} />
      </div>
    </Drawer>
  );
}
