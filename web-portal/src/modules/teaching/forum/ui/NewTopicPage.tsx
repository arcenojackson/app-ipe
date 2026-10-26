"use client";

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

  function toggleTag(id: string) {
    setTagIds((current) => {
      if (current.includes(id)) return current.filter((t) => t !== id);
      return current.length >= LIMITS.tags ? current : [...current, id];
    });
  }

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
    <form onSubmit={submit} className="max-w-2xl space-y-4">
      <h1 className="text-2xl font-semibold">{editId ? "Editar tópico" : "Novo tópico"}</h1>
      <TextField id="topic-title" label="Título" value={title} onChange={(e) => setTitle(e.target.value)} />
      <label htmlFor="topic-body" className="block text-sm text-white/70">
        Mensagem
        <textarea
          id="topic-body"
          rows={8}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          className="mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface focus:border-primary focus:outline-none"
        />
      </label>
      {tags.length > 0 && (
        <fieldset className="space-y-2">
          <legend className="text-sm text-white/70">Assuntos (opcional, até {LIMITS.tags})</legend>
          <div className="flex flex-wrap gap-2">
            {tags.map((t) => (
              <label key={t.id} className="flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm">
                <input type="checkbox" checked={tagIds.includes(t.id)} onChange={() => toggleTag(t.id)} />
                {t.name}
              </label>
            ))}
          </div>
        </fieldset>
      )}
      <RefPicker value={refs} onChange={setRefs} />
      {problem && <p role="alert" className="text-sm text-error">{problem}</p>}
      <Button type="submit" disabled={busy}>{editId ? "Salvar" : "Publicar"}</Button>
    </form>
  );
}
