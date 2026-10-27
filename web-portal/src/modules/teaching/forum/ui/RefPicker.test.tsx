import {fireEvent, render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Ref} from "../types";
import RefPicker from "./RefPicker";

const repo = vi.hoisted(() => ({loadPublishedDocs: vi.fn(), loadPlanLessons: vi.fn()}));
vi.mock("../repository", () => repo);

const doc = (id: string): Ref => ({kind: "library", id, label: `Doc ${id}`});

beforeEach(() => {
  repo.loadPublishedDocs.mockReset().mockResolvedValue([doc("1"), doc("2")]);
  repo.loadPlanLessons.mockReset().mockResolvedValue([{kind: "plan", id: "aula-01", label: "Aula 1 — Fé"}]);
});

describe("RefPicker", () => {
  it("lista só o que o repositório devolve, adiciona e remove", async () => {
    const onChange = vi.fn();
    const {rerender} = render(<RefPicker value={[]} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", {name: "Citar documento ou aula"}));
    fireEvent.click(await screen.findByRole("button", {name: "Doc 1"}));
    expect(onChange).toHaveBeenCalledWith([doc("1")]);
    // o diálogo fecha ao escolher
    expect(screen.queryByRole("dialog")).toBeNull();
    rerender(<RefPicker value={[doc("1")]} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", {name: "Remover citação Doc 1"}));
    expect(onChange).toHaveBeenLastCalledWith([]);
  });

  it("busca por nome e troca para aulas do Plano", async () => {
    render(<RefPicker value={[]} onChange={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Citar documento ou aula"}));
    await screen.findByRole("button", {name: "Doc 1"});
    fireEvent.change(screen.getByLabelText("Buscar documento publicado"), {target: {value: "cate"}});
    fireEvent.click(screen.getByRole("button", {name: "Buscar"}));
    expect(repo.loadPublishedDocs).toHaveBeenLastCalledWith("cate");
    fireEvent.click(screen.getByRole("button", {name: "Plano pedagógico"}));
    expect(await screen.findByRole("button", {name: "Aula 1 — Fé"})).toBeInTheDocument();
  });

  it("não passa de 3 citações", async () => {
    render(<RefPicker value={[doc("a"), doc("b"), doc("c")]} onChange={vi.fn()} />);
    expect(screen.getByRole("button", {name: "Citar documento ou aula"})).toBeDisabled();
  });

  it("erro de carga mostra aviso", async () => {
    repo.loadPublishedDocs.mockRejectedValue(new Error("x"));
    render(<RefPicker value={[]} onChange={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Citar documento ou aula"}));
    expect(await screen.findByText("Não foi possível carregar as opções.")).toBeInTheDocument();
  });
});
