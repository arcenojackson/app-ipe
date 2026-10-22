"use client";

import {useEffect, useState} from "react";
import {loadAllVisible, subscribeFolder} from "./repository";
import type {LibraryItem, Viewer} from "./types";

// Visitante neutro para telas que ainda não conhecem o usuário; constante de
// módulo para não mudar de identidade a cada render (evita laço de efeitos).
export const NO_VIEWER: Viewer = {uid: "", isCurator: false, isAdmin: false};

// A chave descarta respostas de uma pasta anterior: só vale o que corresponde
// à pasta e ao espectador atuais. O primeiro erro é terminal (o repositório
// pode avisar até 3 vezes, uma por consulta).
export function useFolderItems(folderId: string | null, viewer: Viewer) {
  const key = `${viewer.uid}|${viewer.isCurator}|${viewer.isAdmin}|${folderId ?? "raiz"}`;
  const [state, setState] = useState<{
    key: string;
    items: LibraryItem[] | null;
    error: string | null;
  }>({key, items: null, error: null});

  useEffect(() => {
    return subscribeFolder(
      folderId,
      viewer,
      (items) => setState({key, items, error: null}),
      () =>
        setState((prev) =>
          prev.key === key && prev.error ?
            prev :
            {key, items: null, error: "Não foi possível carregar esta pasta."}
        )
    );
  }, [folderId, viewer, key]);

  return state.key === key ? state : {key, items: null, error: null};
}

// Todos os itens visíveis: migalhas, busca por nome e escolha de destino.
export function useCatalog(viewer: Viewer) {
  const [items, setItems] = useState<LibraryItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [round, setRound] = useState(0);

  useEffect(() => {
    let active = true;
    loadAllVisible(viewer)
      .then((list) => {
        if (!active) return;
        setItems(list);
        setError(null);
      })
      .catch(() => active && setError("Não foi possível carregar a biblioteca."));
    return () => {
      active = false;
    };
  }, [viewer, round]);

  return {items, error, reload: () => setRound((r) => r + 1)};
}
