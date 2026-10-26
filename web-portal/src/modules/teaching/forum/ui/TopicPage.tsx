"use client";

import Link from "next/link";
import {useCallback, useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {viewerFrom} from "../../library/types";
import {topicPermissions} from "../permissions";
import {
  createComment,
  editComment,
  loadComments,
  loadMyVotes,
  loadTopic,
  removeComment,
  setTopicFlags,
  setVote,
} from "../repository";
import {buildTree} from "../tree";
import type {Comment, CommentInput, Topic} from "../types";
import CommentForm from "./CommentForm";
import CommentNode, {type CommentActions} from "./CommentNode";
import {formatDate} from "./format";
import ForumText from "./ForumText";
import RefCard from "./RefCard";

const LOAD_ERROR = "Não foi possível carregar o tópico.";

interface Loaded {
  topic: Topic;
  comments: Comment[];
  myVotes: Record<string, 1 | -1>;
}

// Tópico com a árvore de comentários (até 3 níveis). Carrega ao abrir e
// recarrega depois de cada ação do usuário (sem tempo real).
export default function TopicPage({topicId}: {topicId: string}) {
  const {state} = useAuth();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const user = state.status === "signedIn" ? state.user : null;
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const [missing, setMissing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  const uid = viewer?.uid;
  const fetchAll = useCallback(async (): Promise<Loaded | null> => {
    if (!uid) return null;
    const topic = await loadTopic(topicId);
    if (!topic) return null;
    const comments = await loadComments(topicId);
    const votable = comments.filter((c) => !c.deleted && c.authorUid !== uid).map((c) => c.id);
    return {topic, comments, myVotes: await loadMyVotes(topicId, uid, votable)};
  }, [topicId, uid]);

  useEffect(() => {
    let cancelled = false;
    fetchAll()
      .then((result) => {
        if (cancelled) return;
        if (result) setLoaded(result);
        else if (uid) setMissing(true);
      })
      .catch(() => !cancelled && setError(LOAD_ERROR));
    return () => {
      cancelled = true;
    };
  }, [fetchAll, uid]);

  // A gravação já deu certo quando chegamos aqui: falha ao recarregar não
  // pode virar erro de salvar (o usuário repetiria e duplicaria).
  const reload = useCallback(async () => {
    try {
      const result = await fetchAll();
      if (result) setLoaded(result);
    } catch {
      setFailure("Salvo, mas não foi possível atualizar a página. Recarregue.");
    }
  }, [fetchAll]);

  if (!viewer || !user) return null;
  const author = {uid: user.uid, name: user.displayName || user.email || "Professor"};
  const tree = loaded ? buildTree(loaded.comments) : [];

  const actions: CommentActions = {
    async vote(comment, value) {
      const before = loaded?.myVotes[comment.id] ?? 0;
      await setVote(topicId, comment.id, user.uid, value);
      setLoaded((current) => {
        if (!current) return current;
        const myVotes = {...current.myVotes};
        if (value === 0) delete myVotes[comment.id];
        else myVotes[comment.id] = value;
        return {
          ...current,
          myVotes,
          comments: current.comments.map((c) =>
            c.id === comment.id ? {...c, score: c.score + value - before} : c
          ),
        };
      });
    },
    async reply(parent, input) {
      await createComment(topicId, input, author, parent);
      await reload();
    },
    async edit(comment, input) {
      await editComment(topicId, comment.id, input);
      await reload();
    },
    async remove(comment) {
      await removeComment(topicId, comment.id);
      await reload();
    },
  };

  async function moderate(flags: Parameters<typeof setTopicFlags>[1]) {
    setFailure(null);
    try {
      await setTopicFlags(topicId, flags);
      await reload();
    } catch {
      setFailure("Não foi possível concluir a ação. Tente novamente.");
    }
  }

  async function addComment(input: CommentInput) {
    await createComment(topicId, input, author, null);
    await reload();
  }

  if (error) return <p role="alert" className="text-error">{error}</p>;
  if (missing) return <p role="alert" className="text-error">Tópico não encontrado.</p>;
  if (!loaded) return <p className="text-white/70">Carregando…</p>;

  const {topic} = loaded;
  const can = topicPermissions(topic, viewer);

  return (
    <div className="space-y-4">
      <Link href="/ensino/forum" className="text-sm text-white/60 hover:underline">← Fórum</Link>
      <div className="space-y-2 rounded-card bg-surface-elevated p-5">
        <h1 className="text-2xl font-semibold">{topic.title}</h1>
        <p className="text-sm text-white/60">
          {topic.authorName} · {formatDate(topic.createdAt)}
          {topic.editedAt ? " (editado)" : ""}
          {topic.pinned ? " · Fixado" : ""}
          {topic.locked ? " · Trancado" : ""}
        </p>
        {topic.deleted && !can.visibleBody ? (
          <p className="italic text-white/60">Tópico removido</p>
        ) : (
          <>
            {topic.deleted && <p className="italic text-white/60">Tópico removido</p>}
            <ForumText text={topic.body} />
            {topic.refs.length > 0 && (
              <div className="flex flex-wrap gap-2">
                {topic.refs.map((r) => <RefCard key={`${r.kind}-${r.id}`} item={r} />)}
              </div>
            )}
          </>
        )}
        <div className="flex flex-wrap gap-1">
          {can.canEdit && (
            <Link href={`/ensino/forum/novo?editar=${topic.id}`}
              className="rounded-button px-4 py-2 font-semibold hover:bg-white/10">Editar</Link>
          )}
          {can.canPin && (
            <Button type="button" variant="text" onClick={() => void moderate({pinned: !topic.pinned})}>
              {topic.pinned ? "Desafixar" : "Fixar"}
            </Button>
          )}
          {can.canLock && (
            <Button type="button" variant="text" onClick={() => void moderate({locked: !topic.locked})}>
              {topic.locked ? "Destrancar" : "Trancar"}
            </Button>
          )}
          {can.canDelete && (
            <Button type="button" variant="text" onClick={() => {
              if (window.confirm("Apagar este tópico?")) void moderate({deleted: true});
            }}>Apagar</Button>
          )}
        </div>
        {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
      </div>

      {topic.locked && <p className="rounded-card bg-surface-elevated p-4">Tópico trancado.</p>}
      {can.canComment && (
        <CommentForm label="Novo comentário" submitLabel="Comentar" onSubmit={addComment} />
      )}
      {can.visibleBody && (
        <>
          <h2 className="text-lg font-semibold">
            {topic.commentCount} {topic.commentCount === 1 ? "comentário" : "comentários"}
          </h2>
          <ul className="space-y-2">
            {tree.map((node) => (
              <CommentNode key={node.comment.id} node={node} topic={topic} viewer={viewer}
                myVotes={loaded.myVotes} actions={actions} />
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
