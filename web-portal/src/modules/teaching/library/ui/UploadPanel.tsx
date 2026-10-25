"use client";

import {useRef, useState, type DragEvent} from "react";
import {Button} from "@/core/ui/Button";
import {uploadFile} from "../mutations";
import {EMPTY_TAGS, validateTags, type ItemTags} from "../tags";
import {useTags} from "../useTags";
import {TagPicker} from "./TagPicker";
import {UploadError} from "../uploadFlow";

interface Entry {
  key: number;
  name: string;
  progress: number;
  status: "uploading" | "done" | "error";
  message?: string;
}

export function UploadPanel({
  uid,
  onUploaded,
}: {
  uid: string;
  onUploaded: () => void;
}) {
  const [entries, setEntries] = useState<Entry[]>([]);
  const [tags, setTags] = useState<ItemTags>(EMPTY_TAGS);
  const [tagError, setTagError] = useState<string | null>(null);
  const {tags: tagList} = useTags();
  const counter = useRef(0);
  const input = useRef<HTMLInputElement>(null);

  function patch(key: number, changes: Partial<Entry>) {
    setEntries((list) => list.map((e) => (e.key === key ? {...e, ...changes} : e)));
  }

  async function start(files: File[]) {
    const problem = validateTags(tags);
    setTagError(problem);
    if (problem) return;
    for (const file of files) {
      const key = counter.current++;
      setEntries((list) => [...list, {key, name: file.name, progress: 0, status: "uploading"}]);
      try {
        await uploadFile(uid, file, {tags, onProgress: (progress) => patch(key, {progress})});
        patch(key, {status: "done", progress: 1});
        onUploaded();
      } catch (error) {
        const message = error instanceof UploadError ?
          error.message :
          "Não foi possível enviar o arquivo. Tente novamente.";
        patch(key, {status: "error", message});
      }
    }
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    void start(Array.from(event.dataTransfer?.files ?? []));
  }

  return (
    <div className="space-y-3">
      <TagPicker tags={tagList ?? []} value={tags} onChange={setTags} error={tagError} />
      <div
        data-testid="drop-zone"
        onDragOver={(e) => e.preventDefault()}
        onDrop={onDrop}
        className="rounded-card border border-dashed border-white/20 p-4 text-center text-sm text-white/70"
      >
        Arraste arquivos aqui (qualquer tipo, até 100 MB) ou{" "}
        <Button type="button" variant="text" className="px-1 py-0" onClick={() => input.current?.click()}>
          Enviar arquivos
        </Button>
        <input
          ref={input}
          type="file"
          multiple
          aria-label="Escolher arquivos"
          className="hidden"
          onChange={(e) => {
            void start(Array.from(e.target.files ?? []));
            e.target.value = "";
          }}
        />
      </div>
      {entries.length > 0 && (
        <ul className="space-y-1">
          {entries.map((entry) => (
            <li key={entry.key} className="rounded-card bg-surface-elevated px-3 py-2 text-sm">
              <div className="flex items-center justify-between gap-2">
                <span className="truncate">{entry.name}</span>
                <span className={entry.status === "error" ? "text-error" : "text-white/70"}>
                  {entry.status === "uploading" && `${Math.round(entry.progress * 100)}%`}
                  {entry.status === "done" && "Enviado"}
                  {entry.status === "error" && entry.message}
                </span>
              </div>
              {entry.status === "uploading" && <progress className="mt-1 w-full" value={entry.progress} max={1} />}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
