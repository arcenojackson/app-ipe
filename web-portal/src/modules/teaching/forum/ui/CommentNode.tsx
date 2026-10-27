"use client";

import {useState} from "react";
import type {Viewer} from "../../library/types";
import {commentPermissions} from "../permissions";
import type {CommentNodeData} from "../tree";
import type {Comment, CommentInput, Topic} from "../types";
import {ActionMenu, menuItemClass} from "./ActionMenu";
import CommentForm from "./CommentForm";
import {formatDate} from "./format";
import ForumText from "./ForumText";
import {Avatar, Pill} from "./parts";
import RefCard from "./RefCard";

export interface CommentActions {
  vote(comment: Comment, value: 1 | -1 | 0): Promise<void>;
  reply(parent: Comment, input: CommentInput): Promise<void>;
  edit(comment: Comment, input: CommentInput): Promise<void>;
  remove(comment: Comment): Promise<void>;
}

const actionClass = (active: boolean) =>
  `rounded-full px-2.5 py-1 hover:bg-white/10 hover:text-white ${active ? "bg-secondary/30 text-white" : ""}`;

// Um comentário e suas respostas (recuo por nível, com linha-guia). Removido
// vira "[removido]" mas mantém as respostas visíveis.
export default function CommentNode({
  node,
  topic,
  viewer,
  myVotes,
  actions,
}: {
  node: CommentNodeData;
  topic: Topic;
  viewer: Viewer;
  myVotes: Record<string, 1 | -1>;
  actions: CommentActions;
}) {
  const {comment} = node;
  const can = commentPermissions(comment, topic, viewer);
  const [mode, setMode] = useState<"view" | "reply" | "edit">("view");
  const [failure, setFailure] = useState<string | null>(null);
  const current = myVotes[comment.id] ?? 0;

  async function run(action: () => Promise<void>) {
    setFailure(null);
    try {
      await action();
    } catch {
      setFailure("Não foi possível concluir a ação. Tente novamente.");
    }
  }

  return (
    <li>
      <div className="grid grid-cols-[2.25rem_minmax(0,1fr)] gap-3">
        <Avatar name={comment.authorName} />
        <div className="min-w-0">
          <p className="flex flex-wrap items-center gap-2 text-sm text-white/60">
            <b className="font-semibold text-on-surface">{comment.authorName}</b>
            {comment.authorUid === topic.authorUid && <Pill tone="pinned">Autor</Pill>}
            <span>
              {formatDate(comment.createdAt)}
              {comment.editedAt ? " (editado)" : ""}
            </span>
          </p>
          {comment.deleted ? (
            <p className="mt-1 italic text-white/60">[removido]</p>
          ) : mode === "edit" ? (
            <div className="mt-2">
              <CommentForm
                label="Editar comentário"
                submitLabel="Salvar"
                initialBody={comment.body}
                initialRefs={comment.refs}
                onSubmit={async (input) => {
                  await actions.edit(comment, input);
                  setMode("view");
                }}
                onCancel={() => setMode("view")}
              />
            </div>
          ) : (
            <div className="mt-1 space-y-2">
              <ForumText text={comment.body} />
              {comment.refs.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {comment.refs.map((r) => <RefCard key={`${r.kind}-${r.id}`} item={r} />)}
                </div>
              )}
            </div>
          )}
          {!comment.deleted && mode !== "edit" && (
            <div className="mt-1 flex flex-wrap items-center gap-0.5 text-sm text-white/60">
              {can.canVote ? (
                <>
                  <button type="button" aria-label="Curtir" aria-pressed={current === 1}
                    className={actionClass(current === 1)}
                    onClick={() => void run(() => actions.vote(comment, current === 1 ? 0 : 1))}>👍</button>
                  <span aria-label="Saldo de votos" className="min-w-[1.5rem] text-center font-semibold text-on-surface">{comment.score}</span>
                  <button type="button" aria-label="Não curtir" aria-pressed={current === -1}
                    className={actionClass(current === -1)}
                    onClick={() => void run(() => actions.vote(comment, current === -1 ? 0 : -1))}>👎</button>
                </>
              ) : (
                <span aria-label="Saldo de votos" className="px-2 font-semibold text-on-surface">{comment.score}</span>
              )}
              {can.canReply && (
                <button type="button" className={actionClass(false)} onClick={() => setMode("reply")}>Responder</button>
              )}
              {(can.canEdit || can.canDelete) && (
                <ActionMenu label="Mais ações do comentário">
                  {can.canEdit && (
                    <button type="button" role="menuitem" className={menuItemClass} onClick={() => setMode("edit")}>Editar</button>
                  )}
                  {can.canDelete && (
                    <button type="button" role="menuitem" className={`${menuItemClass} text-error`} onClick={() => {
                      if (window.confirm("Apagar este comentário?")) void run(() => actions.remove(comment));
                    }}>Apagar</button>
                  )}
                </ActionMenu>
              )}
            </div>
          )}
          {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
          {mode === "reply" && (
            <div className="mt-2">
              <CommentForm
                label="Sua resposta"
                submitLabel="Responder"
                onSubmit={async (input) => {
                  await actions.reply(comment, input);
                  setMode("view");
                }}
                onCancel={() => setMode("view")}
              />
            </div>
          )}
          {node.children.length > 0 && (
            <ul className="mt-4 space-y-4 border-l-2 border-white/10 pl-4">
              {node.children.map((child) => (
                <CommentNode key={child.comment.id} node={child} topic={topic} viewer={viewer}
                  myVotes={myVotes} actions={actions} />
              ))}
            </ul>
          )}
        </div>
      </div>
    </li>
  );
}
