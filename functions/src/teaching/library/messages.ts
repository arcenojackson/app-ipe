import type {ItemDoc} from "./types";

export interface Message {
  title: string;
  body: string;
}

const MAX_BODY = 200;

function clip(text: string): string {
  return text.length > MAX_BODY ? `${text.slice(0, MAX_BODY - 1)}…` : text;
}

function quoted(item: ItemDoc): string {
  return `"${item.name}"`;
}

export function reviewRequestedMessage(
  item: ItemDoc,
  resubmitted: boolean
): Message {
  return {
    title: resubmitted ?
      "Material reenviado para revisão" :
      "Novo material para revisar",
    body: clip(`${quoted(item)} aguarda a sua revisão.`),
  };
}

export function publishedMessage(item: ItemDoc): Message {
  return {
    title: "Material publicado",
    body: clip(`${quoted(item)} foi aprovado e já está na biblioteca.`),
  };
}

export function returnedMessage(item: ItemDoc, comment: string): Message {
  return {
    title: "Material devolvido",
    body: clip(`${quoted(item)}: ${comment}`),
  };
}

export function rejectedMessage(item: ItemDoc, comments: string[]): Message {
  const reasons = comments.filter((c) => c.length > 0);
  const suffix = reasons.length > 0 ? ` Motivo: ${reasons.join(" | ")}` : "";
  return {
    title: "Material rejeitado",
    body: clip(`${quoted(item)} foi rejeitado pelos curadores.${suffix}`),
  };
}

export function deleteRequestedMessage(item: ItemDoc): Message {
  return {
    title: "Pedido de exclusão",
    body: clip(
      `Foi pedida a exclusão de ${quoted(item)}. Sua aprovação é necessária.`
    ),
  };
}

export function deleteRefusedMessage(item: ItemDoc, comment: string): Message {
  return {
    title: "Exclusão recusada",
    body: clip(`A exclusão de ${quoted(item)} foi recusada: ${comment}`),
  };
}

export function deleteExecutedMessage(item: ItemDoc): Message {
  return {
    title: "Exclusão concluída",
    body: clip(`${quoted(item)} foi excluído da biblioteca.`),
  };
}

export function moveRevertedMessage(item: ItemDoc): Message {
  return {
    title: "Movimento desfeito",
    body: clip(
      `Não foi possível mover ${quoted(item)} para esse local ` +
      "(destino inválido ou profundidade máxima)."
    ),
  };
}
