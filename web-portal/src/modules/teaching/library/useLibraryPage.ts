"use client";

import {useCallback, useEffect, useState} from "react";
import type {LibraryFilters} from "./libraryQuery";
import {loadLibraryPage, type LibraryCursor} from "./repository";
import type {LibraryItem} from "./types";

export const PAGE_SIZE = 20;
const LOAD_ERROR = "Não foi possível carregar a biblioteca.";

interface Data {
  // Filtros (serializados) a que estes dados pertencem.
  key: string;
  items: LibraryItem[];
  cursor: LibraryCursor | null;
  done: boolean;
  loadingMore: boolean;
  error: string | null;
}

// Biblioteca paginada: recarrega do zero quando os filtros mudam (comparados
// por valor) e ignora respostas de consultas antigas.
export function useLibraryPage(filters: LibraryFilters) {
  const key = JSON.stringify(filters);
  const [data, setData] = useState<Data | null>(null);

  useEffect(() => {
    let cancelled = false;
    loadLibraryPage(JSON.parse(key) as LibraryFilters, null, PAGE_SIZE)
      .then((page) => {
        if (cancelled) return;
        setData({key, items: page.items, cursor: page.cursor, done: page.done, loadingMore: false, error: null});
      })
      .catch(() => {
        if (cancelled) return;
        setData({key, items: [], cursor: null, done: false, loadingMore: false, error: LOAD_ERROR});
      });
    return () => {
      cancelled = true;
    };
  }, [key]);

  const current = data && data.key === key ? data : null;

  const loadMore = useCallback(() => {
    if (!current || current.done || current.loadingMore) return;
    setData({...current, loadingMore: true, error: null});
    loadLibraryPage(JSON.parse(key) as LibraryFilters, current.cursor, PAGE_SIZE)
      .then((page) =>
        setData((d) =>
          d && d.key === key ?
            {...d, items: [...d.items, ...page.items], cursor: page.cursor, done: page.done, loadingMore: false} :
            d
        )
      )
      .catch(() => setData((d) => (d && d.key === key ? {...d, loadingMore: false, error: LOAD_ERROR} : d)));
  }, [current, key]);

  return {
    items: current?.items ?? [],
    loading: !current || current.loadingMore,
    error: current?.error ?? null,
    done: current?.done ?? false,
    loadMore,
  };
}
