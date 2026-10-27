"use client";

import {usePathname, useRouter, useSearchParams} from "next/navigation";
import {useEffect} from "react";

// Janelas (item, aula) abrem SOBRE a página atual: a rota de fundo não muda,
// só um parâmetro da URL (`?item=`, `?aula=`). Abrir empilha uma entrada (o
// "voltar" do navegador fecha a janela); fechar volta uma entrada se foi uma
// abertura nossa, ou troca a URL (link direto / recarregada). `scroll: false`
// mantém a posição da página.
//
// A marca vale para o módulo todo: quem abre (ex.: um cartão do Fórum) e quem
// fecha (a página) usam instâncias diferentes do hook.
let openedByUs = false;

export function useOverlayParam(basePath: string, param: string) {
  const router = useRouter();
  const params = useSearchParams();
  const value = params.get(param) || null;

  // Janela fechada por outro caminho (ex.: botão voltar do navegador): zera a marca.
  useEffect(() => {
    if (!value) openedByUs = false;
  }, [value]);

  // Saiu da página (ex.: pelo menu): a marca não vale mais.
  useEffect(() => () => {
    openedByUs = false;
  }, []);

  const open = (id: string) => {
    openedByUs = true;
    router.push(`${basePath}?${param}=${encodeURIComponent(id)}`, {scroll: false});
  };
  const close = () => {
    if (openedByUs) {
      openedByUs = false;
      router.back();
    } else {
      router.replace(basePath, {scroll: false});
    }
  };
  return {value, open, close};
}

export function useItemOverlay(basePath: string) {
  const {value, open, close} = useOverlayParam(basePath, "item");
  return {itemId: value, open, close};
}

// Abre item/aula sobre a página em que o usuário está (qualquer rota).
export function useOverlayOpener() {
  const pathname = usePathname();
  const router = useRouter();
  return (param: "item" | "aula", id: string) => {
    openedByUs = true;
    router.push(`${pathname}?${param}=${encodeURIComponent(id)}`, {scroll: false});
  };
}
