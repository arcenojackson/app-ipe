"use client";

import {useEffect, useState} from "react";
import {loadVotes, subscribeReviewQueue} from "./repository";
import type {ReviewQueue} from "./reviewQueue";
import type {LibraryVote, Viewer} from "./types";

export const QUEUE_ERROR = "Não foi possível carregar a fila de revisão.";

interface Loaded {
  queue: ReviewQueue;
  votes: Record<string, LibraryVote[]>;
}

// Fila ao vivo com os votos de cada item. Só publica a fila depois de ler os
// votos (senão itens que já votei piscariam na tela). O primeiro erro é terminal.
export function useReviewQueue(viewer: Viewer | null) {
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!viewer) return;
    let active = true;
    let failed = false;
    let sequence = 0;
    const stop = subscribeReviewQueue(
      viewer,
      (queue) => {
        if (failed) return;
        const current = ++sequence;
        const ids = [...new Set([...queue.mine, ...queue.toReview, ...queue.returned, ...queue.deleteRequests].map((i) => i.id))];
        Promise.all(ids.map(async (id) => [id, await loadVotes(id).catch((): LibraryVote[] => [])] as const)).then(
          (entries) => {
            if (active && current === sequence) setLoaded({queue, votes: Object.fromEntries(entries)});
          }
        );
      },
      () => {
        if (failed) return;
        failed = true;
        if (active) setError(QUEUE_ERROR);
      }
    );
    return () => {
      active = false;
      stop();
    };
  }, [viewer]);

  return {queue: loaded?.queue ?? null, votes: loaded?.votes ?? {}, error};
}
