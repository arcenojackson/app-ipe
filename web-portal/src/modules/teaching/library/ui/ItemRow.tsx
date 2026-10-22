import type {BadgeTone} from "../status";
import type {LibraryItem} from "../types";
import {StatusBadge} from "./StatusBadge";

const ICONS = {folder: "📁", file: "📄", link: "🔗"} as const;

export function ItemRow({
  item,
  badge,
  view,
  onOpen,
  subtitle,
}: {
  item: LibraryItem;
  badge: {label: string; tone: BadgeTone};
  view: "list" | "grid";
  onOpen: () => void;
  subtitle?: string;
}) {
  const grid = view === "grid";
  return (
    <button
      type="button"
      aria-label={`Abrir ${item.name}`}
      onClick={onOpen}
      className={`rounded-card bg-surface-elevated text-left transition hover:brightness-125 ${
        grid ? "flex flex-col gap-2 p-4" : "flex w-full items-center gap-3 px-4 py-3"
      }`}
    >
      <span aria-hidden className={grid ? "text-3xl" : "text-xl"}>{ICONS[item.type]}</span>
      <span className="min-w-0 flex-1">
        <span className="block truncate font-medium">{item.name}</span>
        {subtitle && <span className="block truncate text-xs text-white/60">{subtitle}</span>}
      </span>
      <StatusBadge badge={badge} />
    </button>
  );
}
