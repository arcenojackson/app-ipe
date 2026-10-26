import Link from "next/link";
import type {Ref} from "../types";

// Citação de documento publicado da Biblioteca ou de aula do Plano. Se o
// alvo sumiu, o link leva à tela de origem, que mostra o estado atual.
export function refHref(item: Ref): string {
  return item.kind === "library" ?
    `/ensino/biblioteca?item=${encodeURIComponent(item.id)}` :
    "/ensino/plano";
}

export default function RefCard({item}: {item: Ref}) {
  return (
    <Link
      href={refHref(item)}
      className="inline-flex items-center gap-2 rounded-input border border-white/10 bg-surface/60 px-3 py-2 text-sm hover:bg-white/10"
    >
      <span className="text-white/60">{item.kind === "library" ? "Documento" : "Aula"}</span>
      <span>{item.label}</span>
    </Link>
  );
}
