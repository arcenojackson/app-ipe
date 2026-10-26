import {tagName, type Tag} from "../tags";

export function TagChips({ids, byId}: {ids: string[]; byId: Map<string, Tag>}) {
  if (ids.length === 0) return null;
  return (
    <ul className="flex flex-wrap gap-1">
      {ids.map((id) => (
        <li key={id} className="rounded-full bg-white/10 px-2 py-0.5 text-xs">
          {tagName(byId, id)}
        </li>
      ))}
    </ul>
  );
}
