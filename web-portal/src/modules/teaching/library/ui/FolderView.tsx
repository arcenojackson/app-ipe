import {statusBadge} from "../status";
import type {LibraryItem} from "../types";
import {ItemRow} from "./ItemRow";

export function FolderView({
  items,
  view,
  onOpen,
  emptyMessage,
  subtitleFor,
}: {
  items: LibraryItem[];
  view: "list" | "grid";
  onOpen: (item: LibraryItem) => void;
  emptyMessage: string;
  subtitleFor?: (item: LibraryItem) => string | undefined;
}) {
  if (items.length === 0) {
    return <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">{emptyMessage}</p>;
  }
  return (
    <div
      data-testid="folder-view"
      data-view={view}
      className={view === "grid" ? "grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4" : "space-y-2"}
    >
      {items.map((item) => (
        <ItemRow
          key={item.id}
          item={item}
          badge={statusBadge(item, null)}
          view={view}
          subtitle={subtitleFor?.(item)}
          onOpen={() => onOpen(item)}
        />
      ))}
    </div>
  );
}
