import {Suspense} from "react";
import {PortalShell} from "@/core/ui/PortalShell";

// O Suspense é exigido (cacheComponents) porque o shell lê o pathname e há
// rotas dinâmicas dentro do portal (ex.: /eleicoes/[id]).
export default function PortalLayout({children}: {children: React.ReactNode}) {
  return (
    <Suspense fallback={<p className="p-6 text-white/70">Carregando…</p>}>
      <PortalShell>{children}</PortalShell>
    </Suspense>
  );
}
