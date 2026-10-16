import {BATCH_SIZE} from "./constants";
import type {ItemDoc, LibraryDb, LibraryDeps} from "./types";
import {chunks} from "./util";

// levels[0] = [raiz], levels[1] = filhos da raiz, e assim por diante.
export async function collectLevels(
  db: LibraryDb,
  root: ItemDoc
): Promise<ItemDoc[][]> {
  const levels: ItemDoc[][] = [[root]];
  let current: ItemDoc[] = [root];
  while (current.length > 0) {
    const next: ItemDoc[] = [];
    for (const item of current) {
      if (item.type !== "folder") continue;
      next.push(...(await db.listChildren(item.id)));
    }
    if (next.length > 0) levels.push(next);
    current = next;
  }
  return levels;
}

// Raiz primeiro, depois filhos em largura.
export async function collectSubtree(
  db: LibraryDb,
  root: ItemDoc
): Promise<ItemDoc[]> {
  return (await collectLevels(db, root)).flat();
}

// Algum documento ou link (qualquer nível)?
export function hasDocuments(items: ItemDoc[]): boolean {
  return items.some((item) => item.type !== "folder");
}

// Arquivos primeiro; depois os documentos nível a nível, do mais fundo para
// cima, terminando cada nível antes do anterior; a raiz por último. Assim um
// pai nunca some antes dos filhos e a retentativa ainda encontra a árvore.
export async function deleteSubtree(
  deps: LibraryDeps,
  root: ItemDoc
): Promise<void> {
  const levels = await collectLevels(deps.db, root);
  const files = levels.flat().filter((item) => item.type === "file");
  for (const part of chunks(files, BATCH_SIZE)) {
    await Promise.all(part.map((i) => deps.storage.deleteItemFiles(i.id)));
  }
  for (let depth = levels.length - 1; depth >= 1; depth--) {
    for (const part of chunks(levels[depth], BATCH_SIZE)) {
      await Promise.all(part.map((i) => deps.db.deleteItem(i.id)));
    }
  }
  await deps.db.deleteItem(root.id);
}
