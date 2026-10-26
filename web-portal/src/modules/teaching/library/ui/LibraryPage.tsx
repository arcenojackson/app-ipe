"use client";

import {useRouter, useSearchParams} from "next/navigation";
import {useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {EMPTY_FILTERS, type LibraryFilters} from "../libraryQuery";
import {loadUserNames} from "../repository";
import {EMPTY_TAGS, type ItemTags} from "../tags";
import {viewerFrom, type Viewer} from "../types";
import {libraryUrl, readParams} from "../url";
import {useLibraryPage} from "../useLibraryPage";
import {useTags} from "../useTags";
import {ItemModal} from "./ItemModal";
import {LibraryTable} from "./LibraryTable";
import {NotificationBell} from "./NotificationBell";
import {TagFilterBar} from "./TagFilterBar";

const SEARCH_DEBOUNCE_MS = 300;

export function LibraryContent({
  viewer,
  itemId,
  navigate,
}: {
  viewer: Viewer;
  itemId: string | null;
  navigate: (url: string) => void;
}) {
  const [tagFilters, setTagFilters] = useState<ItemTags>(EMPTY_TAGS);
  const [text, setText] = useState("");
  const [debouncedText, setDebouncedText] = useState("");
  const [authorNames, setAuthorNames] = useState<Record<string, string>>({});
  const {tags, byId, error: tagsError} = useTags();

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedText(text), SEARCH_DEBOUNCE_MS);
    return () => clearTimeout(timer);
  }, [text]);

  const filters: LibraryFilters = useMemo(
    () => ({...EMPTY_FILTERS, ...tagFilters, text: debouncedText}),
    [tagFilters, debouncedText]
  );
  const library = useLibraryPage(filters);

  // Nomes dos autores: só busca os que ainda não são conhecidos.
  useEffect(() => {
    const missing = [...new Set(library.items.map((i) => i.authorId))].filter(
      (uid) => uid && !(uid in authorNames)
    );
    if (missing.length === 0) return;
    let active = true;
    loadUserNames(missing)
      .then((names) => active && setAuthorNames((known) => ({...known, ...names})))
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, [library.items, authorNames]);

  const empty = library.items.length === 0;
  const showMore = !library.done && !(library.loading && empty);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Biblioteca</h1>
        <NotificationBell uid={viewer.uid} />
      </div>
      <TagFilterBar tags={tags ?? []} value={tagFilters} onChange={setTagFilters} text={text} onTextChange={setText} loadError={tagsError} />
      {library.error && <p role="alert" className="text-sm text-error">{library.error}</p>}
      {library.loading && empty ? (
        <p className="text-white/70">Carregando…</p>
      ) : (
        <>
          {!empty && (
            <LibraryTable
              items={library.items}
              byTagId={byId}
              authorNames={authorNames}
              onOpenFile={(id) => navigate(libraryUrl({item: id}))}
            />
          )}
          {empty && library.done && !library.error && (
            <p className="rounded-card bg-surface-elevated p-6">Nenhum arquivo encontrado.</p>
          )}
          {showMore && (
            <Button type="button" variant="text" disabled={library.loading} onClick={library.loadMore}>
              Carregar mais
            </Button>
          )}
        </>
      )}
      {itemId && <ItemModal itemId={itemId} viewer={viewer} onClose={() => navigate(libraryUrl({}))} onChanged={library.reload} />}
    </div>
  );
}

export default function LibraryPage() {
  const {state} = useAuth();
  const router = useRouter();
  const params = readParams(useSearchParams());
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  if (!viewer) return null;
  return <LibraryContent viewer={viewer} itemId={params.item} navigate={(url) => router.push(url)} />;
}
