import {Suspense} from "react";
import LibraryPage from "@/modules/teaching/library/ui/LibraryPage";

export default function Page() {
  return (
    <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
      <LibraryPage />
    </Suspense>
  );
}
