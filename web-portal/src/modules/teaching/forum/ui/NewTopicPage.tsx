"use client";

import Link from "next/link";
import {useRouter, useSearchParams} from "next/navigation";
import {useEffect, useState, type FormEvent} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {viewerFrom} from "../../library/types";
import {validateTopicInput} from "../payloads";
import {createTopic, editTopic, loadSubjectTags, loadTopic} from "../repository";
import {topicPermissions} from "../permissions";
import {LIMITS, type Ref} from "../types";
import {SubjectMenu} from "./parts";
import RefPicker from "./RefPicker";

const SAVE_ERROR = "Não foi possível publicar. Tente novamente.";

// Cria um tópico, ou edita o próprio quando a URL traz ?editar=<id>.
export default function NewTopicPage() {
  const {state} = useAuth();
  const router = useRouter();
  const editId = useSearchParams().get("editar");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [tagIds, setTagIds] = useState<string[]>([]);
  const [refs, setRefs] = useState<Ref[]>([]);
  const [tags, setTags] = useState<Array<{id: string; name: string}>>([]);
  const [problem, setProblem] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [blocked, setBlocked] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    loadSubjectTags().then((list) => !cancelled && setTags(list)).catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);

  const uid = state.status === "signedIn" ? state.user.uid : null;
  const claims = state.status === "signedIn" ? state.claims : null;

  useEffect(() => {
    if (!editId || !uid || !claims) return;
    let cancelled = false;
    loadTopic(editId)
      .then((topic) => {
        if (cancelled) return;
        if (!topic || !topicPermissions(topic, viewerFrom(uid, claims)).canEdit) {
          setBlocked("Você não pode editar este tópico.");
          return;
        }
        setTitle(topic.title);
        setBody(topic.body);
        setTagIds(topic.tagIds);
        setRefs(topic.refs);
      })
      .catch(() => !cancelled && setBlocked("Não foi possível carregar o tópico."));
    return () => {
      cancelled = true;
    };
  }, [editId, uid, claims]);

  if (state.status !== "signedIn") return null;
  const user = state.user;

  async function submit(event: FormEvent) {
    event.preventDefault();
    const input = {title, body, tagIds, refs};
    const invalid = validateTopicInput(input);
    setProblem(invalid);
    if (invalid) return;
    setBusy(true);
    try {
      const name = user.displayName || user.email || "Professor";
      const id = editId ?? (await createTopic(input, {uid: user.uid, name}));
      if (editId) await editTopic(editId, input);
      router.push(`/ensino/forum/${id}`);
    } catch {
      setProblem(SAVE_ERROR);
      setBusy(false);
    }
  }

  if (blocked) return <p role="alert" className="text-error">{blocked}</p>;

  return (
    <form onSubmit={submit} className="mx-auto max-w-[820px]">
      <Link href={editId ? `/ensino/forum/${editId}` : "/ensino/forum"} className="mb-2 inline-block text-sm text-white/60 hover:underline">← Fórum</Link>
      <h1 className="text-2xl font-semibold">{editId ? "Editar tópico" : "Novo tópico"}</h1>
      <p className="mb-4 text-white/60">Escreva com clareza; os colegas verão o título na lista.</p>
      <div className="mb-3 space-y-4 rounded-card bg-surface p-5">
        <TextField id="topic-title" label="Título" value={title} onChange={(e) => setTitle(e.target.value)} />
        <label htmlFor="topic-body" className="block text-sm text-white/70">
          Mensagem
          <textarea
            id="topic-body"
            rows={7}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            className="mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface focus:border-primary focus:outline-none"
          />
        </label>
      </div>
      <div className="mb-3 space-y-5 rounded-card bg-surface p-5">
        {tags.length > 0 && (
          <div className="space-y-2">
            <p className="flex justify-between text-sm text-white/70">
              <span>Assuntos (opcional)</span>
              <span>{tagIds.length} de {LIMITS.tags}</span>
            </p>
            <SubjectMenu subjects={tags} value={tagIds} onChange={setTagIds} max={LIMITS.tags} label="Escolher assuntos" />
          </div>
        )}
        <div className="space-y-2">
          <p className="text-sm text-white/70">Citações (opcional)</p>
          <RefPicker value={refs} onChange={setRefs} />
        </div>
      </div>
      {problem && <p role="alert" className="mb-2 text-sm text-error">{problem}</p>}
      <div className="sticky bottom-0 -mx-1 flex items-center justify-between gap-3 bg-gradient-to-t from-background from-70% to-transparent px-1 py-3">
        <span className="text-xs text-white/60">Você poderá editar depois.</span>
        <div className="flex gap-2">
          <Link href={editId ? `/ensino/forum/${editId}` : "/ensino/forum"} className="rounded-full border border-white/10 px-5 py-3 text-sm hover:bg-white/10">Cancelar</Link>
          <Button type="submit" disabled={busy} className="!rounded-full !px-6 !py-3">{editId ? "Salvar" : "Publicar"}</Button>
        </div>
      </div>
    </form>
  );
}
