import {Suspense} from "react";
import NewTopicPage from "@/modules/teaching/forum/ui/NewTopicPage";

export default function Page() {
  return (
    <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
      <NewTopicPage />
    </Suspense>
  );
}
