"use client";

import Link from "next/link";
import {useRouter, useSearchParams} from "next/navigation";
import {useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {Icon} from "@/core/ui/icons";
import {EMPTY_FILTERS, type LibraryFilters} from "../libraryQuery";
import {loadUserNames} from "../repository";
import {EMPTY_TAGS, type ItemTags} from "../tags";
import {viewerFrom, type Viewer} from "../types";
import {libraryUrl, readParams} from "../url";
import {useLibraryPage} from "../useLibraryPage";
import {useTags} from "../useTags";
import {ItemModal} from "./ItemModal";
import {ItemSidePanel} from "./ItemSidePanel";
import {LibraryGrid} from "./LibraryGrid";
import {LibraryList} from "./LibraryList";
import {NotificationBell} from "./NotificationBell";
import {TagFilterBar} from "./TagFilterBar";

const SEARCH_DEBOUNCE_MS = 300;
const VIEW_KEY = "ipe-library-view";

type View = "list" | "grid";

function readView(): View {
  try {
    return localStorage.getItem(VIEW_KEY) === "grid" ? "grid" : "list";
  } catch {
    return "list";
  }
}

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
  const [view, setView] = useState<View>("list");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const {tags, byId, error: tagsError} = useTags();

  useEffect(() => {
    // Preferência lida após a montagem para não divergir da renderização do servidor.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setView(readView());
  }, []);

  const chooseView = (next: View) => {
    setView(next);
    try {
      localStorage.setItem(VIEW_KEY, next);
    } catch {
      // sem armazenamento: a escolha vale só nesta visita
    }
  };

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

  const selected = library.items.find((i) => i.id === selectedId) ?? null;
  const open = (id: string) => navigate(libraryUrl({item: id}));

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold">Biblioteca</h1>
        <div className="flex items-center gap-2">
          <Link href="/ensino/revisao" className="inline-flex items-center gap-2 rounded-full bg-secondary px-5 py-2.5 text-sm font-semibold hover:brightness-110">
            <Icon name="plus" className="h-4 w-4" />
            Enviar material
          </Link>
          <NotificationBell uid={viewer.uid} />
        </div>
      </div>
      <TagFilterBar tags={tags ?? []} value={tagFilters} onChange={setTagFilters} text={text} onTextChange={setText} loadError={tagsError} />
      <div role="group" aria-label="Exibição" className="flex gap-2">
        {(["list", "grid"] as const).map((v) => (
          <button
            key={v}
            type="button"
            aria-pressed={view === v}
            onClick={() => chooseView(v)}
            className={`inline-flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm ${view === v ? "border-white/40 bg-white/15" : "border-white/15 text-white/70 hover:bg-white/10"}`}
          >
            <Icon name={v === "list" ? "list" : "grid"} className="h-4 w-4" />
            {v === "list" ? "Lista" : "Grade"}
          </button>
        ))}
      </div>
      {library.error && <p role="alert" className="text-sm text-error">{library.error}</p>}
      {library.loading && empty ? (
        <div role="status" aria-label="Carregando" className="space-y-2">
          {[0, 1, 2, 3].map((n) => <div key={n} className="h-14 animate-pulse rounded-card bg-surface" />)}
        </div>
      ) : (
        <>
          {!empty && (
            <div className={view === "list" && selected ? "grid gap-5 lg:grid-cols-[minmax(0,1fr)_22rem]" : ""}>
              {view === "list" ? (
                <LibraryList
                  items={library.items}
                  byTagId={byId}
                  authorNames={authorNames}
                  selectedId={selected?.id}
                  onSelect={setSelectedId}
                />
              ) : (
                <LibraryGrid items={library.items} authorNames={authorNames} onOpenFile={open} />
              )}
              {view === "list" && selected && (
                <ItemSidePanel
                  item={selected}
                  byTagId={byId}
                  authorName={authorNames[selected.authorId]}
                  onOpen={() => open(selected.id)}
                  onClose={() => setSelectedId(null)}
                />
              )}
            </div>
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
