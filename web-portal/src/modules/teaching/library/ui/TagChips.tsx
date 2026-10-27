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
