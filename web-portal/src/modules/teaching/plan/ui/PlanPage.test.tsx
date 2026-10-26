import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {PlanRow} from "../types";
import PlanPage from "./PlanPage";

const repo = vi.hoisted(() => ({
  subscribePlan: vi.fn(),
  savePlanField: vi.fn(),
  addPlanRow: vi.fn(),
  deletePlanRow: vi.fn(),
}));
vi.mock("../repository", () => repo);

const row = (lesson: number, theme: string, extra: Partial<PlanRow> = {}): PlanRow => ({
  id: `aula-${lesson}`, lesson, theme, leader: "", knowledge: "Inspiração", skills: "", essentials: "", notes: "", references: "", ...extra,
});

let rows: PlanRow[];

function renderAs(role: "teacher" | "curator", uid = role === "curator" ? "c1" : "t1") {
  const state: AuthState = {status: "signedIn", user: {uid} as User, claims: {admin: false, teachingRole: role}};
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <PlanPage />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  rows = [row(1, "O que é ser cristão?", {leader: "Yara"}), row(2, "A Bíblia: Palavra de Deus")];
  repo.subscribePlan.mockReset().mockImplementation((onData) => {
    onData(rows);
    return vi.fn();
  });
  repo.savePlanField.mockReset().mockResolvedValue(undefined);
  repo.addPlanRow.mockReset().mockResolvedValue(undefined);
  repo.deletePlanRow.mockReset().mockResolvedValue(undefined);
});

describe("PlanPage — professor", () => {
  it("vê a tabela com as colunas da planilha, só leitura", () => {
    renderAs("teacher");
    for (const header of ["Aula", "Tema", "Orientador responsável", "Objetos de conhecimento",
      "Habilidades necessárias", "Aprendizagens essenciais", "Observações", "Referências bibliográficas"]) {
      expect(screen.getByRole("columnheader", {name: header})).toBeInTheDocument();
    }
    expect(screen.getByText("O que é ser cristão?")).toBeInTheDocument();
    expect(screen.getByText("Yara")).toBeInTheDocument();
    expect(screen.queryByRole("textbox")).not.toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Adicionar aula"})).not.toBeInTheDocument();
    expect(screen.queryByRole("button", {name: /Apagar aula/})).not.toBeInTheDocument();
  });

  it("plano vazio mostra mensagem", () => {
    rows = [];
    renderAs("teacher");
    expect(screen.getByText("Nenhuma aula no plano ainda.")).toBeInTheDocument();
  });

  it("erro da assinatura vira alerta", () => {
    repo.subscribePlan.mockImplementation((_onData, onError) => {
      onError(new Error("x"));
      return vi.fn();
    });
    renderAs("teacher");
    expect(screen.getByRole("alert")).toHaveTextContent("Não foi possível carregar o plano pedagógico.");
  });
});

describe("PlanPage — curador edita como numa planilha", () => {
  it("alterar o tema e sair do campo salva só aquele campo", async () => {
    renderAs("curator");
    const theme = screen.getByLabelText("Tema da aula 1");
    fireEvent.change(theme, {target: {value: "Novo tema"}});
    fireEvent.blur(theme);
    await waitFor(() => expect(repo.savePlanField).toHaveBeenCalledWith("c1", "aula-1", "theme", "Novo tema"));
    expect(await screen.findByRole("status")).toHaveTextContent("Salvo.");
  });

  it("sair do campo sem alterar não salva", () => {
    renderAs("curator");
    fireEvent.blur(screen.getByLabelText("Tema da aula 1"));
    expect(repo.savePlanField).not.toHaveBeenCalled();
  });

  it("tema vazio mostra erro e não salva", () => {
    renderAs("curator");
    const theme = screen.getByLabelText("Tema da aula 2");
    fireEvent.change(theme, {target: {value: "  "}});
    fireEvent.blur(theme);
    expect(screen.getByRole("alert")).toHaveTextContent("O tema não pode ficar vazio.");
    expect(repo.savePlanField).not.toHaveBeenCalled();
  });

  it("falha ao salvar mostra alerta", async () => {
    repo.savePlanField.mockRejectedValue(new Error("permission-denied"));
    renderAs("curator");
    const field = screen.getByLabelText("Observações da aula 1");
    fireEvent.change(field, {target: {value: "Nota"}});
    fireEvent.blur(field);
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível salvar. Tente novamente.");
  });

  it("Adicionar aula cria a próxima aula", async () => {
    renderAs("curator");
    fireEvent.click(screen.getByRole("button", {name: "Adicionar aula"}));
    await waitFor(() => expect(repo.addPlanRow).toHaveBeenCalledWith("c1", 3, "Novo tema"));
  });

  it("Apagar aula pede confirmação", async () => {
    const confirm = vi.spyOn(window, "confirm").mockReturnValueOnce(false).mockReturnValueOnce(true);
    renderAs("curator");
    fireEvent.click(screen.getByRole("button", {name: "Apagar aula 2"}));
    expect(repo.deletePlanRow).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", {name: "Apagar aula 2"}));
    await waitFor(() => expect(repo.deletePlanRow).toHaveBeenCalledWith("aula-2"));
    confirm.mockRestore();
  });
});
