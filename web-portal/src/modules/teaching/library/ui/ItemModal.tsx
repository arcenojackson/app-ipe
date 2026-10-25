"use client";

import type {Viewer} from "../types";
import {ItemDetail} from "./ItemDetail";

// Janela do item. Provisória (Task 6): mostra o ItemDetail atual; a Task 7
// troca por uma janela com visualização do arquivo.
export function ItemModal({
  itemId,
  viewer,
  onClose,
}: {
  itemId: string;
  viewer: Viewer;
  onClose: () => void;
}) {
  return (
    <ItemDetail
      key={itemId}
      itemId={itemId}
      viewer={viewer}
      folders={[]}
      byId={new Map()}
      onChanged={() => undefined}
      onClose={() => onClose()}
    />
  );
}
