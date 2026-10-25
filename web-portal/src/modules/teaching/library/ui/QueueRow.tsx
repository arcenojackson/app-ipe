import type {BadgeTone} from "../status";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {StatusBadge} from "./StatusBadge";
import {TagChips} from "./TagChips";

// Linha da Fila de Revisão: nome, tags, selo de status e, quando há, o andamento.
export function QueueRow({
  item,
  badge,
  byTagId,
  note,
  progress,
  onOpen,
}: {
  item: LibraryItem;
  badge: {label: string; tone: BadgeTone};
  byTagId: Map<string, Tag>;
  // Texto de apoio (comentário de devolução, motivo da exclusão).
  note?: string;
  // Ex.: "1/2 aprovações".
  progress?: string;
  onOpen: () => void;
}) {
  return (
    <div className="space-y-1">
      <button
        type="button"
        aria-label={`Abrir ${item.name}`}
        onClick={onOpen}
        className="flex w-full items-center gap-3 rounded-card bg-surface-elevated px-4 py-3 text-left transition hover:brightness-125"
      >
        <span aria-hidden className="text-xl">{item.type === "link" ? "🔗" : "📄"}</span>
        <span className="min-w-0 flex-1 space-y-1">
          <span className="block truncate font-medium">{item.name}</span>
          <TagChips
            ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
            byId={byTagId}
          />
          {note && <span className="block truncate text-xs text-white/60">{note}</span>}
        </span>
        <StatusBadge badge={badge} />
      </button>
      {progress && <p className="px-4 text-xs text-white/60">{progress}</p>}
    </div>
  );
}
