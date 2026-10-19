import type {LibraryItem} from "./types";

export function mergeById(lists: LibraryItem[][]): LibraryItem[] {
  const byId = new Map<string, LibraryItem>();
  for (const list of lists) {
    for (const item of list) byId.set(item.id, item);
  }
  return [...byId.values()];
}
