import type {Metadata} from "next";
import {Suspense} from "react";
import {VotePage} from "@/modules/elections/pages/VotePage";

export const metadata: Metadata = {
  title: "Votação — IPE",
  description: "Votação da diretoria.",
};

// Com cacheComponents, ler `params` fora de um Suspense bloqueia o prerender.
async function VoteRoute({params}: {params: Promise<{id: string}>}) {
  const {id} = await params;
  return <VotePage electionId={id} />;
}

export default function Page({params}: {params: Promise<{id: string}>}) {
  return (
    <Suspense
      fallback={<p className="p-6 text-sm text-white/70">Carregando...</p>}
    >
      <VoteRoute params={params} />
    </Suspense>
  );
}
