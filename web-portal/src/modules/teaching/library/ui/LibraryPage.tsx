"use client";

import {useRouter, useSearchParams} from "next/navigation";
import {useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {sortItems, buildBreadcrumbs, filterByName, indexById} from "../tree";
import type {LibraryItem, Viewer} from "../types";
import {viewerFrom} from "../types";
import {useCatalog, useFolderItems} from "../useLibrary";
import {libraryUrl, readParams} from "../url";
import {Breadcrumbs} from "./Breadcrumbs";
import {FolderView} from "./FolderView";

export function LibraryContent({
  viewer,
  folderId,
  itemId,
  navigate: navigateTo,
}: {
  viewer: Viewer;
  folderId: string | null;
  itemId: string | null;
  navigate: (url: string) => void;
}) {
  const [view, setView] = useState<"list" | "grid">("list");
  const [search, setSearch] = useState("");
  // Navegar sempre sai do modo busca.
  const navigate = (url: string) => {
    setSearch("");
    navigateTo(url);
  };
  const catalog = useCatalog(viewer);
  const folder = useFolderItems(folderId, viewer);

  const byId = useMemo(() => indexById(catalog.items ?? []), [catalog.items]);
  const trail = buildBreadcrumbs(byId, folderId);
  const missingFolder =
    folderId !== null && catalog.items !== null && !byId.has(folderId);
  const searching = search.trim().length > 0;

  const shown = searching ?
    sortItems(filterByName(catalog.items ?? [], search)) :
    sortItems(folder.items ?? []);

  function open(item: LibraryItem) {
    if (item.type === "folder") {
      navigate(libraryUrl({pasta: item.id}));
    } else {
      navigate(libraryUrl({pasta: item.parentId, item: item.id}));
    }
  }

  function pathOf(item: LibraryItem): string | undefined {
    const names = buildBreadcrumbs(byId, item.parentId).map((f) => f.name);
    return names.length > 0 ? names.join(" / ") : "Biblioteca";
  }

  if (missingFolder) {
    return (
      <div className="space-y-4">
        <p className="rounded-card bg-surface-elevated p-6">Pasta não encontrada ou sem acesso.</p>
        <Button type="button" onClick={() => navigate(libraryUrl({}))}>Voltar para a biblioteca</Button>
      </div>
    );
  }

  const error = searching ? catalog.error : folder.error ?? catalog.error;
  const loading = searching ?
    catalog.items === null && !catalog.error :
    folder.items === null && !folder.error;
  const showList = !loading && !(searching ? catalog.error : folder.error);

  return (
    <div className="space-y-4" data-item={itemId ?? undefined}>
      <h1 className="text-2xl font-semibold">Biblioteca</h1>
      <Breadcrumbs trail={trail} onNavigate={navigate} />
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-[14rem] flex-1">
          <TextField id="library-search" label="Buscar na biblioteca" value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
        <div className="flex gap-2">
          <Button type="button" variant="text" aria-pressed={view === "list"} onClick={() => setView("list")}>Ver em lista</Button>
          <Button type="button" variant="text" aria-pressed={view === "grid"} onClick={() => setView("grid")}>Ver em grade</Button>
        </div>
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {loading ? (
        <p className="text-white/70">Carregando…</p>
      ) : showList && (
        <FolderView
          items={shown}
          view={view}
          onOpen={open}
          subtitleFor={searching ? pathOf : undefined}
          emptyMessage={searching ? "Nada encontrado." : "Esta pasta está vazia."}
        />
      )}
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
  return (
    <LibraryContent
      viewer={viewer}
      folderId={params.pasta}
      itemId={params.item}
      navigate={(url) => router.push(url)}
    />
  );
}
