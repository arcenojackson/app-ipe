"use client";

import {useRouter, useSearchParams} from "next/navigation";
import {useRef} from "react";

// A janela do item abre SOBRE a página atual: a rota de fundo não muda, só o
// `?item=`. Abrir empilha uma entrada (o "voltar" do navegador fecha a janela);
// fechar volta uma entrada se fomos nós que abrimos, ou troca a URL (link
// direto). `scroll: false` mantém a posição da página.
export function useItemOverlay(basePath: string) {
  const router = useRouter();
  const params = useSearchParams();
  const openedHere = useRef(false);
  const itemId = params.get("item") || null;

  const open = (id: string) => {
    openedHere.current = true;
    router.push(`${basePath}?item=${encodeURIComponent(id)}`, {scroll: false});
  };
  const close = () => {
    if (openedHere.current) {
      openedHere.current = false;
      router.back();
    } else {
      router.replace(basePath, {scroll: false});
    }
  };
  return {itemId, open, close};
}
