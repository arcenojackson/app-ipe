import {libraryUrl} from "../url";
import type {LibraryItem} from "../types";

export function Breadcrumbs({
  trail,
  onNavigate,
}: {
  trail: LibraryItem[];
  onNavigate: (url: string) => void;
}) {
  return (
    <nav aria-label="Caminho" className="flex flex-wrap items-center gap-1 text-sm">
      <button type="button" className="rounded-button px-2 py-1 hover:bg-white/10" onClick={() => onNavigate(libraryUrl({}))}>
        Biblioteca
      </button>
      {trail.map((folder) => (
        <span key={folder.id} className="flex items-center gap-1">
          <span aria-hidden className="text-white/40">/</span>
          <button type="button" className="rounded-button px-2 py-1 hover:bg-white/10" onClick={() => onNavigate(libraryUrl({pasta: folder.id}))}>
            {folder.name}
          </button>
        </span>
      ))}
    </nav>
  );
}
