"use client";

import type {Viewer} from "../types";
import {Dialog} from "./Dialog";
import {ItemDetail} from "./ItemDetail";

// Janela do item: visualização do arquivo (ou link), tags, autor, histórico e
// ações de curadoria. Abre por `?item=` em qualquer tela.
export function ItemModal({
  itemId,
  viewer,
  onClose,
  onChanged,
}: {
  itemId: string;
  viewer: Viewer;
  onClose: () => void;
  onChanged?: () => void;
}) {
  return (
    <Dialog title="Detalhes do item" onClose={onClose} wide hideTitle>
      <ItemDetail key={itemId} itemId={itemId} viewer={viewer} onClose={onClose} onChanged={onChanged ?? (() => undefined)} />
    </Dialog>
  );
}
