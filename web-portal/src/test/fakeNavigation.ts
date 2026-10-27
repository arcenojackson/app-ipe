import {useMemo, useSyncExternalStore} from "react";

// Roteador simulado com histórico (substitui "next/navigation" nos testes de
// integração): push/replace/back/forward mexem numa pilha de URLs e quem usa
// usePathname/useSearchParams/useRouter é re-renderizado, como no Next.
const state = {stack: ["/"], index: 0};
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((listener) => listener());
const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};
const current = () => state.stack[state.index];
const parse = () => new URL(current(), "http://portal.test");

export const nav = {
  // Reinicia o histórico numa URL (ex.: página recarregada com ?item=).
  reset(url = "/") {
    state.stack = [url];
    state.index = 0;
    emit();
  },
  get url() {
    return current();
  },
  get pathname() {
    return parse().pathname;
  },
  get search() {
    return parse().search;
  },
  get length() {
    return state.stack.length;
  },
  get index() {
    return state.index;
  },
  // Botão voltar / avançar do navegador.
  back() {
    if (state.index > 0) state.index -= 1;
    emit();
  },
  forward() {
    if (state.index < state.stack.length - 1) state.index += 1;
    emit();
  },
};

const router = {
  push(url: string) {
    state.stack = [...state.stack.slice(0, state.index + 1), url];
    state.index += 1;
    emit();
  },
  replace(url: string) {
    state.stack = [...state.stack.slice(0, state.index), url];
    emit();
  },
  back: () => nav.back(),
  forward: () => nav.forward(),
  refresh: () => undefined,
  prefetch: () => undefined,
};

export const useRouter = () => router;
export const usePathname = () => useSyncExternalStore(subscribe, () => nav.pathname, () => nav.pathname);
export const useSearchParams = () => {
  const search = useSyncExternalStore(subscribe, () => nav.search, () => nav.search);
  return useMemo(() => new URLSearchParams(search), [search]);
};

// redirect() do servidor (páginas de rota): lança com o destino, como o Next.
export class RedirectSignal extends Error {
  constructor(public readonly url: string) {
    super(url);
  }
}
export function redirect(url: string): never {
  throw new RedirectSignal(url);
}
