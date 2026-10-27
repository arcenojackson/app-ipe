"use client";

import Link from "next/link";
import {useCallback, useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {ItemModal} from "../../library/ui/ItemModal";
import {useOverlayParam} from "../../library/useItemOverlay";
import {viewerFrom} from "../../library/types";
import PlanLessonModal from "../../plan/ui/PlanLessonModal";
import {usePathname} from "next/navigation";
import {topicPermissions} from "../permissions";
import {
  createComment,
  editComment,
  loadComments,
  loadMyVotes,
  loadSubjectTags,
  loadTopic,
  removeComment,
  setTopicFlags,
  setVote,
} from "../repository";
import {buildTree} from "../tree";
import type {Comment, CommentInput, Topic} from "../types";
import {ActionMenu, MenuHeading, menuItemClass} from "./ActionMenu";
import CommentForm from "./CommentForm";
import CommentNode, {type CommentActions} from "./CommentNode";
import {formatDate} from "./format";
import ForumText from "./ForumText";
import {Avatar, Pill} from "./parts";
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
  const [tagNames, setTagNames] = useState<Record<string, string>>({});
  // Citações abrem em janela sobre o tópico (?item= documento, ?aula= aula).
  const pathname = usePathname();
  const itemOverlay = useOverlayParam(pathname, "item");
  const lessonOverlay = useOverlayParam(pathname, "aula");

  useEffect(() => {
    let cancelled = false;
    loadSubjectTags()
      .then((list) => !cancelled && setTagNames(Object.fromEntries(list.map((t) => [t.id, t.name]))))
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);

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
  if (!loaded) return (
    <div className="mx-auto max-w-[820px] space-y-3" aria-busy="true">
      <p className="sr-only">Carregando…</p>
      <div className="h-40 animate-pulse rounded-card bg-surface" />
      <div className="h-20 animate-pulse rounded-card bg-surface" />
    </div>
  );

  const {topic} = loaded;
  const can = topicPermissions(topic, viewer);

  return (
    <div className="mx-auto max-w-[820px]">
      <Link href="/ensino/forum" className="mb-2 inline-block text-sm text-white/60 hover:underline">← Fórum</Link>
      <div className="mb-4 rounded-card bg-surface p-5 sm:p-6">
        <div className="flex items-start justify-between gap-3">
          <div className="flex flex-wrap items-center gap-2">
            {topic.pinned && <Pill tone="pinned">Fixado</Pill>}
            {topic.locked && <Pill>Trancado</Pill>}
            {topic.tagIds.map((id) => <Pill key={id} tone="subject">{tagNames[id] ?? id}</Pill>)}
          </div>
          {(can.canEdit || can.canPin || can.canLock || can.canDelete) && (
            <ActionMenu label="Ações do tópico">
              {can.canEdit && (
                <Link href={`/ensino/forum/novo?editar=${topic.id}`} role="menuitem" className={menuItemClass}>Editar</Link>
              )}
              {(can.canPin || can.canLock || can.canDelete) && can.canEdit && <MenuHeading>Moderação</MenuHeading>}
              {can.canPin && (
                <button type="button" role="menuitem" className={menuItemClass} onClick={() => void moderate({pinned: !topic.pinned})}>
                  {topic.pinned ? "Desafixar" : "Fixar"}
                </button>
              )}
              {can.canLock && (
                <button type="button" role="menuitem" className={menuItemClass} onClick={() => void moderate({locked: !topic.locked})}>
                  {topic.locked ? "Destrancar" : "Trancar"}
                </button>
              )}
              {can.canDelete && (
                <button type="button" role="menuitem" className={`${menuItemClass} text-error`} onClick={() => {
                  if (window.confirm("Apagar este tópico?")) void moderate({deleted: true});
                }}>Apagar</button>
              )}
            </ActionMenu>
          )}
        </div>
        <h1 className="mt-2 text-2xl font-semibold">{topic.title}</h1>
        <p className="mt-2 flex items-center gap-2 text-sm text-white/60">
          <Avatar name={topic.authorName} small />
          <span>
            <b className="font-semibold text-on-surface">{topic.authorName}</b> · {formatDate(topic.createdAt)}
            {topic.editedAt ? " (editado)" : ""}
          </span>
        </p>
        <div className="mt-4 space-y-3">
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
        </div>
        {failure && <p role="alert" className="mt-3 text-sm text-error">{failure}</p>}
      </div>

      {can.visibleBody && (
        <>
          <h2 className="mb-3 mt-6 text-base font-semibold">
            {topic.commentCount} {topic.commentCount === 1 ? "comentário" : "comentários"}
          </h2>
          <ul className="space-y-4 pb-4">
            {tree.map((node) => (
              <CommentNode key={node.comment.id} node={node} topic={topic} viewer={viewer}
                myVotes={loaded.myVotes} actions={actions} />
            ))}
          </ul>
        </>
      )}
      {topic.locked && <p className="mb-4 rounded-card bg-surface p-4">Tópico trancado.</p>}
      {can.canComment && (
        <div className="sticky bottom-0 -mx-1 rounded-t-card bg-surface px-4 py-3 shadow-[0_-10px_30px_rgba(0,0,0,.4)]">
          <CommentForm label="Novo comentário" submitLabel="Comentar" onSubmit={addComment} />
        </div>
      )}
      {itemOverlay.value && viewer && (
        <ItemModal itemId={itemOverlay.value} viewer={viewer} onClose={itemOverlay.close} />
      )}
      {lessonOverlay.value && <PlanLessonModal id={lessonOverlay.value} onClose={lessonOverlay.close} />}
    </div>
  );
}
