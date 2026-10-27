import {TAG_KIND_STYLE} from "../tagKindStyle";
import {tagName, type Tag} from "../tags";

export function TagChips({ids, byId}: {ids: string[]; byId: Map<string, Tag>}) {
  if (ids.length === 0) return null;
  return (
    <ul className="flex flex-wrap gap-1">
      {ids.map((id) => {
        const kind = byId.get(id)?.kind;
        const tone = kind ? TAG_KIND_STYLE[kind].chip : "border-transparent bg-white/10";
        return (
          <li key={id} className={`rounded-full border px-2 py-0.5 text-xs ${tone}`}>
            {tagName(byId, id)}
          </li>
        );
      })}
    </ul>
  );
}

// Versão compacta (cartões da grade): até `max` chips pequenos numa linha e "+N"
// com todos os nomes no title. Mantém a altura fixa para alinhar os cartões.
export function CompactTagChips({ids, byId, max = 3}: {ids: string[]; byId: Map<string, Tag>; max?: number}) {
  if (ids.length === 0) return <div className="h-5" aria-hidden />;
  const shown = ids.slice(0, max);
  const rest = ids.slice(max);
  return (
    <ul className="flex h-5 flex-nowrap gap-1 overflow-hidden">
      {shown.map((id) => {
        const kind = byId.get(id)?.kind;
        const tone = kind ? TAG_KIND_STYLE[kind].chip : "border-transparent bg-white/10";
        return (
          <li key={id} className={`min-w-0 truncate rounded-full border px-1.5 text-[11px] leading-4 ${tone}`}>
            {tagName(byId, id)}
          </li>
        );
      })}
      {rest.length > 0 && (
        <li
          title={ids.map((id) => tagName(byId, id)).join(", ")}
          className="shrink-0 rounded-full border border-transparent bg-white/10 px-1.5 text-[11px] leading-4"
        >
          +{rest.length}
        </li>
      )}
    </ul>
  );
}
