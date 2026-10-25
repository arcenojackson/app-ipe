import {compareNames, normalizeText} from "./text";
import type {LibraryItem} from "./types";

export function sortItems(items: LibraryItem[]): LibraryItem[] {
  return [...items].sort((a, b) => {
    const folderA = a.type === "folder" ? 0 : 1;
    const folderB = b.type === "folder" ? 0 : 1;
    return folderA - folderB || compareNames(a.name, b.name);
  });
}

export function indexById(items: LibraryItem[]): Map<string, LibraryItem> {
  return new Map(items.map((item) => [item.id, item]));
}

// Da raiz até a pasta. Para se um pai não está disponível ou há ciclo.
export function buildBreadcrumbs(
  byId: Map<string, LibraryItem>,
  folderId: string | null
): LibraryItem[] {
  const trail: LibraryItem[] = [];
  const seen = new Set<string>();
  let current = folderId;
  while (current !== null) {
    if (seen.has(current)) break;
    seen.add(current);
    const folder = byId.get(current);
    if (!folder) return [];
    trail.unshift(folder);
    current = folder.parentId;
  }
  return trail;
}

export function filterByName(items: LibraryItem[], term: string): LibraryItem[] {
  const needle = normalizeText(term.trim());
  if (!needle) return items;
  return items.filter((item) => normalizeText(item.name).includes(needle));
}
