import {useOverlayOpener} from "../../library/useItemOverlay";
import type {Ref} from "../types";

// Citação de documento publicado da Biblioteca ou de aula do Plano. Abre uma
// janela SOBRE o tópico (?item= ou ?aula= na rota atual); se o alvo sumiu, a
// própria janela mostra o estado atual.
// Selo do tipo da citação (documento ou aula).
export function RefBadge({item}: {item: Pick<Ref, "kind">}) {
  const library = item.kind === "library";
  return (
    <span
      aria-hidden
      className={`grid h-8 w-8 shrink-0 place-items-center rounded-[10px] text-[10px] font-extrabold ${
        library ? "bg-[#5b1f2b] text-[#ff8da1]" : "bg-[#1f3a5b] text-[#8dbcff]"
      }`}
    >
      {library ? "DOC" : "AULA"}
    </span>
  );
}

export default function RefCard({item}: {item: Ref}) {
  const openOverlay = useOverlayOpener();
  return (
    <button
      type="button"
      onClick={() => openOverlay(item.kind === "library" ? "item" : "aula", item.id)}
      className="flex max-w-md items-center gap-3 rounded-input bg-surface-elevated px-3 py-2 text-left text-sm hover:bg-white/10"
    >
      <RefBadge item={item} />
      <span className="min-w-0 flex-1">
        <span className="block truncate font-medium">{item.label}</span>
        <span className="block text-xs text-white/60">{item.kind === "library" ? "Documento" : "Aula"}</span>
      </span>
    </button>
  );
}
