import {act, renderHook, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {EMPTY_FILTERS} from "./libraryQuery";
import type {LibraryItem} from "./types";
import {useLibraryPage} from "./useLibraryPage";

const repo = vi.hoisted(() => ({loadLibraryPage: vi.fn()}));
vi.mock("./repository", () => repo);

const item = (id: string): LibraryItem => ({
  id, type: "file", name: id, parentId: null, authorId: "a", status: "published", version: 1,
});

beforeEach(() => {
  repo.loadLibraryPage.mockReset();
});

describe("useLibraryPage", () => {
  it("carrega a primeira página e acrescenta a próxima com o cursor anterior", async () => {
    repo.loadLibraryPage
      .mockResolvedValueOnce({items: [item("a")], cursor: "c1", done: false})
      .mockResolvedValueOnce({items: [item("b")], cursor: "c2", done: true});
    const {result} = renderHook(() => useLibraryPage(EMPTY_FILTERS));
    await waitFor(() => expect(result.current.items.map((i) => i.id)).toEqual(["a"]));
    expect(result.current.done).toBe(false);
    act(() => result.current.loadMore());
    await waitFor(() => expect(result.current.items.map((i) => i.id)).toEqual(["a", "b"]));
    expect(repo.loadLibraryPage).toHaveBeenLastCalledWith(EMPTY_FILTERS, "c1", expect.any(Number));
    expect(result.current.done).toBe(true);
  });

  it("mudar os filtros zera a lista e ignora a resposta atrasada da consulta antiga", async () => {
    let resolveOld: (v: unknown) => void = () => undefined;
    repo.loadLibraryPage
      .mockImplementationOnce(() => new Promise((r) => { resolveOld = r; }))
      .mockResolvedValueOnce({items: [item("novo")], cursor: null, done: true});
    const {result, rerender} = renderHook(({f}) => useLibraryPage(f), {initialProps: {f: EMPTY_FILTERS}});
    rerender({f: {...EMPTY_FILTERS, text: "fé"}});
    await waitFor(() => expect(result.current.items.map((i) => i.id)).toEqual(["novo"]));
    await act(async () => resolveOld({items: [item("velho")], cursor: null, done: true}));
    expect(result.current.items.map((i) => i.id)).toEqual(["novo"]);
  });

  it("filtros iguais por valor não recarregam", async () => {
    repo.loadLibraryPage.mockResolvedValue({items: [item("a")], cursor: null, done: true});
    const {rerender, result} = renderHook(({f}) => useLibraryPage(f), {initialProps: {f: {...EMPTY_FILTERS}}});
    await waitFor(() => expect(result.current.items).toHaveLength(1));
    rerender({f: {...EMPTY_FILTERS}});
    expect(repo.loadLibraryPage).toHaveBeenCalledTimes(1);
  });

  it("erro vira mensagem em pt-BR", async () => {
    repo.loadLibraryPage.mockRejectedValue(new Error("boom"));
    const {result} = renderHook(() => useLibraryPage(EMPTY_FILTERS));
    await waitFor(() => expect(result.current.error).toBe("Não foi possível carregar a biblioteca."));
    expect(result.current.loading).toBe(false);
  });
});
