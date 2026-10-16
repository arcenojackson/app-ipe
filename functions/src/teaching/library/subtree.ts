import {BATCH_SIZE} from "./constants";
import type {ItemDoc, LibraryDb, LibraryDeps} from "./types";
import {chunks} from "./util";

// Raiz primeiro, depois filhos em largura.
export async function collectSubtree(
  db: LibraryDb,
  root: ItemDoc
): Promise<ItemDoc[]> {
  const result: ItemDoc[] = [root];
  const queue: ItemDoc[] = [root];
  while (queue.length > 0) {
    const current = queue.shift() as ItemDoc;
    if (current.type !== "folder") continue;
    const children = await db.listChildren(current.id);
    result.push(...children);
    queue.push(...children);
  }
  return result;
}

// Algum documento ou link (qualquer nível)?
export function hasDocuments(items: ItemDoc[]): boolean {
  return items.some((item) => item.type !== "folder");
}

// Arquivos primeiro; documentos de baixo para cima; a raiz por último, para a
// retentativa ainda encontrar a árvore se algo falhar no meio.
export async function deleteSubtree(
  deps: LibraryDeps,
  root: ItemDoc
): Promise<void> {
  const items = await collectSubtree(deps.db, root);
  const files = items.filter((item) => item.type === "file");
  for (const part of chunks(files, BATCH_SIZE)) {
    await Promise.all(part.map((i) => deps.storage.deleteItemFiles(i.id)));
  }
  const children = items.filter((item) => item.id !== root.id).reverse();
  for (const part of chunks(children, BATCH_SIZE)) {
    await Promise.all(part.map((i) => deps.db.deleteItem(i.id)));
  }
  await deps.db.deleteItem(root.id);
}
