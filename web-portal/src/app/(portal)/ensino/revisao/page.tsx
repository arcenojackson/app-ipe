import {Suspense} from "react";
import ReviewQueuePage from "@/modules/teaching/library/ui/ReviewQueuePage";

export default function Page() {
  return (
    <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
      <ReviewQueuePage />
    </Suspense>
  );
}
