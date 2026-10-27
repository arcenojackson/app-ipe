import {fireEvent, render, screen, within} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {LibraryGrid} from "./LibraryGrid";

const names = ["Artigos", "Justificação pela fé", "Ministério Pastoral", "UMP", "Adolescentes"];
const byTagId = new Map<string, Tag>(
  names.map((name, n) => [`t${n}`, {id: `t${n}`, kind: (["type", "subject", "subject", "age", "age"] as const)[n], name, order: n, active: true}])
);

const item = (over: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "f1", type: "file", name: "Santidade", parentId: null, authorId: "u1", status: "published", version: 1,
  publishedAt: Date.UTC(2026, 9, 27, 15), approvedBy: ["c1", "c2"],
  typeTags: ["t0"], subjectTags: ["t1", "t2"], ageTags: ["t3", "t4"], ...over,
});

describe("LibraryGrid", () => {
  it("mostra título, todas as tags por extenso e o autor; sem data, sem Aprovado por e sem +N", () => {
    render(<LibraryGrid items={[item()]} authorNames={{u1: "Jackson Arceno", c1: "Edilaine", c2: "demo"}} byTagId={byTagId} onOpenFile={vi.fn()} />);
    const card = within(screen.getByRole("button", {name: /Santidade/}));
    expect(card.getByText("Santidade")).toBeInTheDocument();
    for (const name of names) expect(card.getByText(name)).toBeInTheDocument();
    expect(card.queryByText(/^\+\d+$/)).not.toBeInTheDocument();
    expect(card.getByText("Jackson Arceno")).toBeInTheDocument();
    expect(card.queryByText(/27\/10\/2026/)).not.toBeInTheDocument();
    expect(card.queryByText(/Aprovado por/)).not.toBeInTheDocument();
  });

  it("clicar no cartão abre o arquivo", () => {
    const onOpenFile = vi.fn();
    render(<LibraryGrid items={[item()]} authorNames={{}} byTagId={byTagId} onOpenFile={onOpenFile} />);
    fireEvent.click(screen.getByRole("button", {name: /Santidade/}));
    expect(onOpenFile).toHaveBeenCalledWith("f1");
  });
});
