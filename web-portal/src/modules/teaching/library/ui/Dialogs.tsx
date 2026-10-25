"use client";

import {useState, type FormEvent, type ReactNode} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {validateDescription, validateName, validateUrl} from "../files";
import {EMPTY_TAGS, validateTags, type ItemTags} from "../tags";
import {useTags} from "../useTags";
import {TagPicker} from "./TagPicker";
import {buildBreadcrumbs} from "../tree";
import type {LibraryItem} from "../types";
import {Dialog} from "./Dialog";

const GENERIC_ERROR = "Não foi possível concluir. Tente novamente.";

// Estado comum: erro de validação, erro de envio e "ocupado".
function useSubmit(onClose: () => void) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function run(problem: string | null, action: () => Promise<void>) {
    if (problem) {
      setError(problem);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await action();
      onClose();
      setBusy(false);
    } catch {
      setError(GENERIC_ERROR);
      setBusy(false);
    }
  }
  return {error, busy, run};
}

function Actions({busy, submitLabel, onClose}: {busy: boolean; submitLabel: string; onClose: () => void}) {
  return (
    <div className="mt-4 flex justify-end gap-2">
      <Button type="button" variant="text" onClick={onClose}>Cancelar</Button>
      <Button type="submit" disabled={busy}>{submitLabel}</Button>
    </div>
  );
}

function ErrorLine({error}: {error: string | null}) {
  return error ? <p role="alert" className="mt-2 text-sm text-error">{error}</p> : null;
}

export function TextPromptDialog({
  title, label, initial = "", submitLabel, validate, onSubmit, onClose,
}: {
  title: string;
  label: string;
  initial?: string;
  submitLabel: string;
  validate: (value: string) => string | null;
  onSubmit: (value: string) => Promise<void>;
  onClose: () => void;
}) {
  const [value, setValue] = useState(initial);
  const {error, busy, run} = useSubmit(onClose);
  return (
    <Dialog title={title} onClose={onClose}>
      <form onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(validate(value), () => onSubmit(value));
      }}>
        <TextField id="prompt-value" label={label} value={value} onChange={(e) => setValue(e.target.value)} autoFocus />
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

export function LinkDialog({
  title = "Adicionar link", initial, submitLabel, withTags = false, onSubmit, onClose,
}: {
  title?: string;
  initial?: {name: string; url: string; description: string};
  submitLabel: string;
  // Pede uma tag de cada tipo (criação de link novo).
  withTags?: boolean;
  onSubmit: (value: {name: string; url: string; description: string; tags?: ItemTags}) => Promise<void>;
  onClose: () => void;
}) {
  const [tags, setTags] = useState<ItemTags>(EMPTY_TAGS);
  const {tags: tagList} = useTags();
  const [name, setName] = useState(initial?.name ?? "");
  const [url, setUrl] = useState(initial?.url ?? "");
  const [description, setDescription] = useState(initial?.description ?? "");
  const {error, busy, run} = useSubmit(onClose);
  return (
    <Dialog title={title} onClose={onClose}>
      <form className="space-y-3" onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(
          validateName(name) ?? validateUrl(url) ?? validateDescription(description) ??
            (withTags ? validateTags(tags) : null),
          () => onSubmit(withTags ? {name, url, description, tags} : {name, url, description})
        );
      }}>
        <TextField id="link-name" label="Nome" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        <TextField id="link-url" label="Endereço (URL)" value={url} onChange={(e) => setUrl(e.target.value)} />
        <TextField id="link-description" label="Descrição (opcional)" value={description} onChange={(e) => setDescription(e.target.value)} />
        {withTags && <TagPicker tags={tagList ?? []} value={tags} onChange={setTags} />}
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

// Curador corrige ou acrescenta tags (no momento da revisão ou depois).
export function TagEditDialog({
  initial, onSubmit, onClose,
}: {
  initial: ItemTags;
  onSubmit: (tags: ItemTags) => Promise<void>;
  onClose: () => void;
}) {
  const [tags, setTags] = useState<ItemTags>(initial);
  const {tags: tagList} = useTags();
  const {error, busy, run} = useSubmit(onClose);
  return (
    <Dialog title="Editar tags" onClose={onClose} wide>
      <form onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(validateTags(tags), () => onSubmit(tags));
      }}>
        <TagPicker tags={tagList ?? []} value={tags} onChange={setTags} />
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel="Salvar tags" onClose={onClose} />
      </form>
    </Dialog>
  );
}

export function ReasonDialog({
  title, label, required = false, submitLabel, onSubmit, onClose,
}: {
  title: string;
  label: string;
  required?: boolean;
  submitLabel: string;
  onSubmit: (text: string) => Promise<void>;
  onClose: () => void;
}) {
  const [text, setText] = useState("");
  const {error, busy, run} = useSubmit(onClose);
  function problem(): string | null {
    const size = text.trim().length;
    if (required && size === 0) return "Escreva um comentário.";
    if (size > 1000) return "O comentário pode ter no máximo 1000 caracteres.";
    return null;
  }
  return (
    <Dialog title={title} onClose={onClose}>
      <form onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(problem(), () => onSubmit(text));
      }}>
        <label htmlFor="reason-text" className="block text-sm text-white/70">
          {label}
          <textarea id="reason-text" rows={4} value={text} onChange={(e) => setText(e.target.value)}
            className="mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface focus:border-primary focus:outline-none" />
        </label>
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

// Pastas para onde o item pode ir: nunca ele mesmo nem seus descendentes.
export function eligibleTargets(
  item: LibraryItem,
  folders: LibraryItem[],
  byId: Map<string, LibraryItem>
): LibraryItem[] {
  return folders.filter((folder) => {
    if (folder.id === item.id) return false;
    if (item.type !== "folder") return true;
    return !buildBreadcrumbs(byId, folder.id).some((p) => p.id === item.id);
  });
}

export function MoveDialog({
  item, folders, byId, onPick, onClose,
}: {
  item: LibraryItem;
  folders: LibraryItem[];
  byId: Map<string, LibraryItem>;
  onPick: (parentId: string | null) => Promise<void>;
  onClose: () => void;
}) {
  const {error, busy, run} = useSubmit(onClose);
  const targets = eligibleTargets(item, folders, byId);
  const pathOf = (folder: LibraryItem) => buildBreadcrumbs(byId, folder.id).map((p) => p.name).join(" / ");
  const choice = (label: ReactNode, parentId: string | null, key: string) => (
    <li key={key}>
      <button type="button" disabled={busy} onClick={() => void run(null, () => onPick(parentId))}
        className="w-full rounded-button px-3 py-2 text-left hover:bg-white/10 disabled:opacity-50">
        {label}
      </button>
    </li>
  );
  return (
    <Dialog title={`Mover "${item.name}"`} onClose={onClose}>
      <ul className="max-h-72 space-y-1 overflow-y-auto">
        {choice("Biblioteca (raiz)", null, "raiz")}
        {targets.map((folder) => choice(pathOf(folder), folder.id, folder.id))}
      </ul>
      <ErrorLine error={error} />
      <div className="mt-4 flex justify-end">
        <Button type="button" variant="text" onClick={onClose}>Cancelar</Button>
      </div>
    </Dialog>
  );
}
