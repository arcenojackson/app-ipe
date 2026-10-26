"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import type {Viewer} from "../../library/types";
import {commentPermissions} from "../permissions";
import type {CommentNodeData} from "../tree";
import type {Comment, CommentInput, Topic} from "../types";
import CommentForm from "./CommentForm";
import {formatDate} from "./format";
import ForumText from "./ForumText";
import RefCard from "./RefCard";

export interface CommentActions {
  vote(comment: Comment, value: 1 | -1 | 0): Promise<void>;
  reply(parent: Comment, input: CommentInput): Promise<void>;
  edit(comment: Comment, input: CommentInput): Promise<void>;
  remove(comment: Comment): Promise<void>;
}

// Um comentário e suas respostas (recuo por nível). Removido vira
// "[removido]" mas mantém as respostas visíveis.
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
    <li className="space-y-2">
      <div className="rounded-card bg-surface-elevated p-4">
        <p className="text-sm text-white/60">
          {comment.authorName} · {formatDate(comment.createdAt)}
          {comment.editedAt ? " (editado)" : ""}
        </p>
        {comment.deleted ? (
          <p className="italic text-white/60">[removido]</p>
        ) : mode === "edit" ? (
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
        ) : (
          <>
            <ForumText text={comment.body} />
            {comment.refs.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-2">
                {comment.refs.map((r) => <RefCard key={`${r.kind}-${r.id}`} item={r} />)}
              </div>
            )}
          </>
        )}
        {!comment.deleted && mode !== "edit" && (
          <div className="mt-2 flex flex-wrap items-center gap-1 text-sm">
            {can.canVote ? (
              <>
                <Button type="button" variant="text" aria-label="Curtir" aria-pressed={current === 1}
                  onClick={() => void run(() => actions.vote(comment, current === 1 ? 0 : 1))}>👍</Button>
                <span aria-label="Saldo de votos">{comment.score}</span>
                <Button type="button" variant="text" aria-label="Não curtir" aria-pressed={current === -1}
                  onClick={() => void run(() => actions.vote(comment, current === -1 ? 0 : -1))}>👎</Button>
              </>
            ) : (
              <span aria-label="Saldo de votos">{comment.score}</span>
            )}
            {can.canReply && <Button type="button" variant="text" onClick={() => setMode("reply")}>Responder</Button>}
            {can.canEdit && <Button type="button" variant="text" onClick={() => setMode("edit")}>Editar</Button>}
            {can.canDelete && (
              <Button type="button" variant="text" onClick={() => {
                if (window.confirm("Apagar este comentário?")) void run(() => actions.remove(comment));
              }}>Apagar</Button>
            )}
          </div>
        )}
        {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
      </div>
      {mode === "reply" && (
        <div className="ml-6">
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
        <ul className="ml-6 space-y-2 border-l border-white/10 pl-3">
          {node.children.map((child) => (
            <CommentNode key={child.comment.id} node={child} topic={topic} viewer={viewer}
              myVotes={myVotes} actions={actions} />
          ))}
        </ul>
      )}
    </li>
  );
}
