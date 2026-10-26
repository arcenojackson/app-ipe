"use client";

import {useState, type FormEvent} from "react";
import {Button} from "@/core/ui/Button";
import {validateCommentInput} from "../payloads";
import type {CommentInput, Ref} from "../types";
import RefPicker from "./RefPicker";

const SAVE_ERROR = "Não foi possível salvar. Tente novamente.";

// Formulário de comentário, resposta ou edição.
export default function CommentForm({
  label,
  submitLabel,
  initialBody = "",
  initialRefs = [],
  onSubmit,
  onCancel,
}: {
  label: string;
  submitLabel: string;
  initialBody?: string;
  initialRefs?: Ref[];
  onSubmit: (input: CommentInput) => Promise<void>;
  onCancel?: () => void;
}) {
  const [body, setBody] = useState(initialBody);
  const [refs, setRefs] = useState<Ref[]>(initialRefs);
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    const input = {body, refs};
    const invalid = validateCommentInput(input);
    setProblem(invalid);
    if (invalid) return;
    setBusy(true);
    try {
      await onSubmit(input);
      setBody("");
      setRefs([]);
    } catch {
      setProblem(SAVE_ERROR);
    }
    setBusy(false);
  }

  return (
    <form onSubmit={submit} className="space-y-2">
      <label className="block text-sm text-white/70">
        {label}
        <textarea
          rows={4}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          className="mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface focus:border-primary focus:outline-none"
        />
      </label>
      <RefPicker value={refs} onChange={setRefs} />
      {problem && <p role="alert" className="text-sm text-error">{problem}</p>}
      <div className="flex gap-2">
        <Button type="submit" disabled={busy}>{submitLabel}</Button>
        {onCancel && <Button type="button" variant="text" onClick={onCancel}>Cancelar</Button>}
      </div>
    </form>
  );
}
