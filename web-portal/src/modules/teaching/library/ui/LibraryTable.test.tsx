import {fireEvent, render, screen, within} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {LibraryTable} from "./LibraryTable";

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

const props = {byTagId, authorNames: {u1: "Felipe"}, onOpenFile: vi.fn()};

describe("LibraryTable", () => {
  it("mostra nome, chips de tag, autor, data e tamanho", () => {
    render(<LibraryTable items={[file()]} {...props} />);
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
    render(<LibraryTable items={[file({authorId: "x"})]} {...props} />);
    expect(within(screen.getByRole("row", {name: /Santidade/})).getByText("—", {selector: "td"})).toBeInTheDocument();
  });

  it("clicar num arquivo chama onOpenFile com o id", () => {
    const onOpenFile = vi.fn();
    render(<LibraryTable items={[file()]} {...props} onOpenFile={onOpenFile} />);
    fireEvent.click(screen.getByRole("button", {name: /Santidade/}));
    expect(onOpenFile).toHaveBeenCalledWith("f1");
  });

  it("link vira âncora com target _blank e rel noopener noreferrer, sem abrir a janela", () => {
    const onOpenFile = vi.fn();
    render(
      <LibraryTable items={[file({id: "l1", type: "link", name: "Livro", url: "https://x.org/livro", size: undefined})]}
        {...props} onOpenFile={onOpenFile} />
    );
    const anchor = screen.getByRole("link", {name: /Livro/});
    expect(anchor).toHaveAttribute("href", "https://x.org/livro");
    expect(anchor).toHaveAttribute("target", "_blank");
    expect(anchor).toHaveAttribute("rel", "noopener noreferrer");
    fireEvent.click(anchor);
    expect(onOpenFile).not.toHaveBeenCalled();
  });

  it("link com esquema diferente de http(s) não vira âncora", () => {
    render(<LibraryTable items={[file({id: "l2", type: "link", name: "Ruim", url: "javascript:alert(1)"})]} {...props} />);
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
    expect(screen.getByText("Ruim")).toBeInTheDocument();
  });

  it("tag removida aparece como Tag removida", () => {
    render(<LibraryTable items={[file({subjectTags: ["assunto-sumiu"]})]} {...props} />);
    expect(screen.getByText("Tag removida")).toBeInTheDocument();
  });
});
