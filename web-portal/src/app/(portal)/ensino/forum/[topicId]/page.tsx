import {Suspense} from "react";
import TopicPage from "@/modules/teaching/forum/ui/TopicPage";

// Rota dinâmica sob o layout do portal (usePathname na casca): sem isso o
// build com cacheComponents recusa o prerender.
export const instant = false;

async function TopicRoute({params}: {params: Promise<{topicId: string}>}) {
  const {topicId} = await params;
  return <TopicPage topicId={topicId} />;
}

export default function Page({params}: {params: Promise<{topicId: string}>}) {
  return (
    <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
      <TopicRoute params={params} />
    </Suspense>
  );
}
