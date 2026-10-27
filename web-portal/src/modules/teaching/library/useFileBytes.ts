"use client";

import {useEffect, useState} from "react";
import {fileBytes} from "./storageAccess";
import {fileErrorMessage} from "./storageErrors";

// Lê os bytes do arquivo só quando `enabled`. O resultado fica ligado ao caminho
// pedido, então trocar de arquivo nunca mostra os bytes do anterior.
export function useFileBytes(storagePath: string | undefined, enabled: boolean) {
  const [result, setResult] = useState<{
    path: string;
    bytes: ArrayBuffer | null;
    error: string | null;
  } | null>(null);

  useEffect(() => {
    if (!enabled || !storagePath) return;
    let active = true;
    fileBytes(storagePath)
      .then((bytes) => active && setResult({path: storagePath, bytes, error: null}))
      .catch(
        (e) =>
          active &&
          setResult({path: storagePath, bytes: null, error: fileErrorMessage(e, "Não foi possível ler o arquivo.")})
      );
    return () => {
      active = false;
    };
  }, [storagePath, enabled]);

  const current = enabled && storagePath && result?.path === storagePath ? result : null;
  return {
    bytes: current?.bytes ?? null,
    error: current?.error ?? null,
    loading: enabled && !!storagePath && !current,
  };
}
