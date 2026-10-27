import {act, renderHook} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {useItemOverlay} from "./useItemOverlay";

const nav = vi.hoisted(() => ({push: vi.fn(), replace: vi.fn(), back: vi.fn(), search: ""}));
vi.mock("next/navigation", () => ({
  useRouter: () => ({push: nav.push, replace: nav.replace, back: nav.back}),
  useSearchParams: () => new URLSearchParams(nav.search),
}));

beforeEach(() => {
  nav.push.mockReset();
  nav.replace.mockReset();
  nav.back.mockReset();
  nav.search = "";
});

describe("useItemOverlay", () => {
  it("lê ?item= e abre empilhando a URL da própria página, sem rolar", () => {
    nav.search = "item=a%20b";
    const {result} = renderHook(() => useItemOverlay("/ensino/revisao"));
    expect(result.current.itemId).toBe("a b");
    act(() => result.current.open("x y"));
    expect(nav.push).toHaveBeenCalledWith("/ensino/revisao?item=x%20y", {scroll: false});
  });

  it("fechar depois de abrir aqui volta uma entrada; sem abrir aqui troca a URL", () => {
    const {result} = renderHook(() => useItemOverlay("/ensino/revisao"));
    act(() => result.current.close());
    expect(nav.replace).toHaveBeenCalledWith("/ensino/revisao", {scroll: false});
    act(() => result.current.open("x"));
    act(() => result.current.close());
    expect(nav.back).toHaveBeenCalledTimes(1);
    act(() => result.current.close());
    expect(nav.replace).toHaveBeenCalledTimes(2);
  });
});
