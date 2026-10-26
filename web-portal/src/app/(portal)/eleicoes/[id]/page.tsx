import {Suspense} from "react";
import {ConductPage} from "@/modules/elections/pages/ConductPage";

// Com cacheComponents, ler `params` fora de um Suspense bloqueia o prerender.
async function ConductRoute({params}: {params: Promise<{id: string}>}) {
  const {id} = await params;
  return <ConductPage electionId={id} />;
}

export default function Page({params}: {params: Promise<{id: string}>}) {
  return (
    <Suspense fallback={<p className="p-6 text-sm text-white/70">Carregando…</p>}>
      <ConductRoute params={params} />
    </Suspense>
  );
}
