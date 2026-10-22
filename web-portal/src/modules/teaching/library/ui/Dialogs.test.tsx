import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {indexById} from "../tree";
import type {LibraryItem} from "../types";
import {LinkDialog, MoveDialog, ReasonDialog, TextPromptDialog, eligibleTargets} from "./Dialogs";

describe("TextPromptDialog", () => {
  const setup = (onSubmit = vi.fn().mockResolvedValue(undefined)) => {
    const onClose = vi.fn();
    render(<TextPromptDialog title="Nova pasta" label="Nome da pasta" submitLabel="Criar" validate={(v) => (v.trim() ? null : "Informe um nome.")} onSubmit={onSubmit} onClose={onClose} />);
    return {onSubmit, onClose};
  };

  it("envia o valor e fecha", async () => {
    const {onSubmit, onClose} = setup();
    fireEvent.change(screen.getByLabelText("Nome da pasta"), {target: {value: "  Crianças "}});
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith("  Crianças "));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("mostra o erro de validação e não envia", () => {
    const {onSubmit} = setup();
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Informe um nome.");
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it("mostra o erro do envio e mantém o diálogo aberto", async () => {
    const {onClose} = setup(vi.fn().mockRejectedValue(new Error("permission-denied")));
    fireEvent.change(screen.getByLabelText("Nome da pasta"), {target: {value: "A"}});
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível concluir. Tente novamente.");
    expect(onClose).not.toHaveBeenCalled();
  });

  it("Escape fecha", () => {
    const {onClose} = setup();
    fireEvent.keyDown(window, {key: "Escape"});
    expect(onClose).toHaveBeenCalled();
  });
});

describe("LinkDialog", () => {
  it("valida nome e endereço antes de enviar", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<LinkDialog submitLabel="Adicionar" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Informe um nome.");
    fireEvent.change(screen.getByLabelText("Nome"), {target: {value: "Livro"}});
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "ftp://x"}});
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Use um endereço que comece com http:// ou https://.");
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://x.org"}});
    fireEvent.change(screen.getByLabelText("Descrição (opcional)"), {target: {value: "Bom livro"}});
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith({name: "Livro", url: "https://x.org", description: "Bom livro"}));
  });

  it("recusa descrição acima de 1000 caracteres", () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<LinkDialog submitLabel="Adicionar" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Nome"), {target: {value: "Livro"}});
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://x.org"}});
    fireEvent.change(screen.getByLabelText("Descrição (opcional)"), {target: {value: "x".repeat(1001)}});
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("A descrição pode ter no máximo 1000 caracteres.");
    expect(onSubmit).not.toHaveBeenCalled();
  });
});

describe("ReasonDialog", () => {
  it("obrigatório recusa vazio e texto longo demais", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ReasonDialog title="Devolver" label="Comentário" required submitLabel="Devolver" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Escreva um comentário.");
    fireEvent.change(screen.getByLabelText("Comentário"), {target: {value: "x".repeat(1001)}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    expect(screen.getByRole("alert")).toHaveTextContent("O comentário pode ter no máximo 1000 caracteres.");
    fireEvent.change(screen.getByLabelText("Comentário"), {target: {value: "Falta a referência"}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith("Falta a referência"));
  });

  it("opcional aceita vazio", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ReasonDialog title="Pedir exclusão" label="Motivo (opcional)" submitLabel="Pedir exclusão" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Pedir exclusão"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith(""));
  });
});

describe("eligibleTargets e MoveDialog", () => {
  const f = (id: string, name: string, parentId: string | null = null): LibraryItem => ({
    id, name, type: "folder", parentId, authorId: "c1", status: "active", version: 1,
  });
  const folders = [f("A", "Crianças"), f("B", "Antigo", "A"), f("C", "Gênesis", "B"), f("D", "Jovens")];
  const byId = indexById(folders);

  it("não oferece a própria pasta nem descendentes", () => {
    expect(eligibleTargets(folders[0], folders, byId).map((i) => i.id)).toEqual(["D"]);
    expect(eligibleTargets(folders[1], folders, byId).map((i) => i.id)).toEqual(["A", "D"]);
  });

  it("arquivo pode ir para qualquer pasta", () => {
    const file: LibraryItem = {id: "x", name: "Aula", type: "file", parentId: "A", authorId: "t", status: "published", version: 1};
    expect(eligibleTargets(file, folders, byId).map((i) => i.id)).toEqual(["A", "B", "C", "D"]);
  });

  it("MoveDialog lista a raiz e as pastas e devolve a escolha", async () => {
    const onPick = vi.fn().mockResolvedValue(undefined);
    render(<MoveDialog item={folders[2]} folders={folders} byId={byId} onPick={onPick} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca (raiz)"}));
    await waitFor(() => expect(onPick).toHaveBeenCalledWith(null));
    fireEvent.click(screen.getByRole("button", {name: "Crianças / Antigo"}));
    await waitFor(() => expect(onPick).toHaveBeenCalledWith("B"));
  });
});
