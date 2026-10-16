import {MAX_DEPTH} from "./constants";
import type {ItemDoc, LibraryDb} from "./types";

// Altura da subárvore: níveis abaixo do item (0 para arquivo ou pasta vazia).
async function subtreeHeight(db: LibraryDb, item: ItemDoc): Promise<number> {
  if (item.type !== "folder") return 0;
  const children = await db.listChildren(item.id);
  let height = 0;
  for (const child of children) {
    height = Math.max(height, 1 + (await subtreeHeight(db, child)));
  }
  return height;
}

// `item` já traz o novo parentId (o documento foi gravado). Inválido se o pai
// não existe ou não é pasta, se há ciclo, ou se o nível total passa do limite.
export async function moveIsValid(
  db: LibraryDb,
  item: ItemDoc
): Promise<boolean> {
  let ancestors = 0;
  if (item.parentId !== null) {
    const seen = new Set<string>([item.id]);
    let current = await db.getItem(item.parentId);
    while (current) {
      if (seen.has(current.id)) return false;
      if (current.type !== "folder") return false;
      seen.add(current.id);
      ancestors++;
      if (ancestors > MAX_DEPTH) return false;
      if (current.parentId === null) break;
      current = await db.getItem(current.parentId);
    }
    if (!current) return false;
  }
  const height = await subtreeHeight(db, item);
  return ancestors + 1 + height <= MAX_DEPTH;
}
