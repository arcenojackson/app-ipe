import {fireEvent, render, screen, within} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {LibraryList} from "./LibraryList";

const tag = (id: string, kind: Tag["kind"], name: string): Tag => ({id, kind, name, order: 1, active: true});
const byTagId = new Map([
  ["tipo-artigos", tag("tipo-artigos", "type", "Artigos")],
  ["assunto-trindade", tag("assunto-trindade", "subject", "Trindade")],
  ["faixa-ump", tag("faixa-ump", "age", "UMP")],
]);

const file = (over: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "f1", type: "file", name: "Santidade", parentId: null, authorId: "u1", status: "published", version: 1,
  size: 250 * 1024, publishedAt: Date.UTC(2026, 9, 19, 15),
  typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"], ...over,
});

const props = {byTagId, authorNames: {u1: "Felipe"}, onSelect: vi.fn()};

describe("LibraryList", () => {
  it("mostra nome, chips de tag, autor, data e tamanho", () => {
    render(<LibraryList items={[file()]} {...props} />);
    const row = screen.getByRole("row", {name: /Santidade/});
    const cells = within(row);
    expect(cells.getByText("Artigos")).toBeInTheDocument();
    expect(cells.getByText("Trindade")).toBeInTheDocument();
    expect(cells.getByText("UMP")).toBeInTheDocument();
    expect(cells.getByText("Felipe")).toBeInTheDocument();
    expect(cells.getByText("19/10/2026")).toBeInTheDocument();
    expect(cells.getByText("250 KB")).toBeInTheDocument();
  });

  it("autor desconhecido aparece como traço", () => {
    render(<LibraryList items={[file({authorId: "x"})]} {...props} />);
    // Autor desconhecido e item ainda sem approvedBy (antes do backfill): um traço em cada coluna.
    expect(within(screen.getByRole("row", {name: /Santidade/})).getAllByText("—", {selector: "td"})).toHaveLength(2);
  });

  it("coluna Aprovado por: primeiros nomes, +N e title com todos; sem campo mostra traço", () => {
    const names = {u1: "Felipe", c1: "Ana Curadora", c2: "Bia Souza", c3: "Caio Lima"};
    render(<LibraryList items={[file({approvedBy: ["c1", "c2", "c3"]})]} {...props} authorNames={names} />);
    const titled = within(screen.getByRole("row", {name: /Santidade/})).getAllByTitle("Ana Curadora, Bia Souza, Caio Lima");
    // Coluna (lg+) e linha secundária sob o nome (abaixo de lg).
    expect(titled.map((el) => el.tagName)).toEqual(["SPAN", "TD"]);
    expect(titled[1]).toHaveTextContent("Ana, Bia +1");
    expect(titled[0]).toHaveTextContent("Aprovado por Ana, Bia +1");
  });

  it("clicar num arquivo chama onSelect com o id", () => {
    const onSelect = vi.fn();
    render(<LibraryList items={[file()]} {...props} onSelect={onSelect} />);
    fireEvent.click(screen.getByRole("button", {name: /Santidade/}));
    expect(onSelect).toHaveBeenCalledWith("f1");
  });

  it("clicar em qualquer célula da linha (tags, autor, data, tamanho) seleciona o arquivo", () => {
    const onSelect = vi.fn();
    render(<LibraryList items={[file()]} {...props} onSelect={onSelect} />);
    for (const text of ["Artigos", "Felipe", "19/10/2026", "250 KB"]) {
      fireEvent.click(screen.getByText(text));
    }
    expect(onSelect).toHaveBeenCalledTimes(4);
    expect(onSelect).toHaveBeenCalledWith("f1");
    expect(screen.getByRole("row", {name: /Santidade/})).toHaveClass("cursor-pointer");
  });

  it("clicar no botão do nome seleciona uma vez só", () => {
    const onSelect = vi.fn();
    render(<LibraryList items={[file()]} {...props} onSelect={onSelect} />);
    fireEvent.click(screen.getByRole("button", {name: /Santidade/}));
    expect(onSelect).toHaveBeenCalledTimes(1);
  });

  it("linha de link não é clicável fora da âncora", () => {
    const onSelect = vi.fn();
    render(<LibraryList items={[file({id: "l3", type: "link", name: "Livro", url: "https://x.org", size: undefined})]} {...props} onSelect={onSelect} />);
    fireEvent.click(screen.getByText("Felipe"));
    expect(onSelect).not.toHaveBeenCalled();
  });

  it("link vira âncora com target _blank e rel noopener noreferrer, sem abrir a janela", () => {
    const onSelect = vi.fn();
    render(
      <LibraryList items={[file({id: "l1", type: "link", name: "Livro", url: "https://x.org/livro", size: undefined})]}
        {...props} onSelect={onSelect} />
    );
    const anchor = screen.getByRole("link", {name: /Livro/});
    expect(anchor).toHaveAttribute("href", "https://x.org/livro");
    expect(anchor).toHaveAttribute("target", "_blank");
    expect(anchor).toHaveAttribute("rel", "noopener noreferrer");
    fireEvent.click(anchor);
    expect(onSelect).not.toHaveBeenCalled();
  });

  it("link com esquema diferente de http(s) não vira âncora", () => {
    render(<LibraryList items={[file({id: "l2", type: "link", name: "Ruim", url: "javascript:alert(1)"})]} {...props} />);
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
    expect(screen.getByText("Ruim")).toBeInTheDocument();
  });

  it("tag removida aparece como Tag removida", () => {
    render(<LibraryList items={[file({subjectTags: ["assunto-sumiu"]})]} {...props} />);
    expect(screen.getByText("Tag removida")).toBeInTheDocument();
  });
});
