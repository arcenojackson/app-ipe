"use client";

import {useEffect, useState} from "react";
import {canReadVotes, loadUserNames, subscribeItem, subscribeVotes} from "./repository";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

export const ITEM_ACCESS_ERROR = "Item não encontrado ou sem acesso.";

export function useItemDetail(itemId: string, viewer: Viewer) {
  const [loaded, setLoaded] = useState<{
    id: string;
    item: LibraryItem | null;
    error: string | null;
  } | null>(null);
  const [voteState, setVoteState] = useState<{id: string; list: LibraryVote[]; loaded: boolean; failed: boolean}>(
    {id: itemId, list: [], loaded: false, failed: false}
  );
  const [names, setNames] = useState<Record<string, string>>({});
  const [authorNames, setAuthorNames] = useState<Record<string, string>>({});

  useEffect(() => {
    // Para professor, item inexistente também chega como permission-denied; o
    // primeiro erro é terminal (o Firestore já encerrou a escuta).
    let failed = false;
    return subscribeItem(
      itemId,
      (item) => {
        if (!failed) setLoaded({id: itemId, item, error: null});
      },
      () => {
        failed = true;
        setLoaded({id: itemId, item: null, error: ITEM_ACCESS_ERROR});
      }
    );
  }, [itemId]);

  const item = loaded?.id === itemId ? loaded.item : undefined;
  const readable = item ? canReadVotes(item, viewer) : false;

  useEffect(() => {
    if (!readable) return;
    return subscribeVotes(
      itemId,
      (list) => setVoteState({id: itemId, list, loaded: true, failed: false}),
      () => setVoteState({id: itemId, list: [], loaded: false, failed: true})
    );
  }, [itemId, readable]);

  const votesCurrent = voteState.id === itemId && readable;
  const votes = votesCurrent ? voteState.list : [];
  const votesLoaded = votesCurrent && voteState.loaded;
  const votesError = votesCurrent && voteState.failed;
  const voterKey = [...new Set(votes.map((v) => v.voterId))].sort().join(",");

  useEffect(() => {
    if (!voterKey) return;
    let active = true;
    loadUserNames(voterKey.split(",")).then((map) => active && setNames(map));
    return () => {
      active = false;
    };
  }, [voterKey]);

  const authorId = item?.authorId;
  const approvedKey = (item?.approvedBy ?? []).join(",");
  useEffect(() => {
    if (!authorId) return;
    let active = true;
    loadUserNames([authorId, ...(approvedKey ? approvedKey.split(",") : [])])
      .then((map) => active && setAuthorNames((known) => ({...known, ...map})))
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, [authorId, approvedKey]);

  return {
    item,
    error: loaded?.id === itemId ? loaded.error : null,
    votes,
    votesLoaded,
    votesError,
    names,
    authorName: authorId ? authorNames[authorId] : undefined,
    approverNames: (item?.approvedBy ?? []).map((id) => authorNames[id] ?? "Curador"),
  };
}
