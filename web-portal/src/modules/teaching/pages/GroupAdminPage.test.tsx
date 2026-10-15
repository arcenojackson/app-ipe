import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {MemberRow} from "../data/memberRows";
import GroupAdminPage from "./GroupAdminPage";

const repo = vi.hoisted(() => ({
  listMembers: vi.fn(),
  setTeachingRole: vi.fn(),
}));

vi.mock("../data/membersRepository", () => repo);

const rows: MemberRow[] = [
  {id: "u1", name: "Ana", email: "ana@ipe.org", isAdmin: false, isPending: false, teachingRole: "none"},
  {id: "u2", name: "Bia", email: "bia@ipe.org", isAdmin: true, isPending: false, teachingRole: "teacher"},
];

beforeEach(() => {
  repo.listMembers.mockReset().mockResolvedValue(rows);
  repo.setTeachingRole.mockReset().mockResolvedValue(undefined);
});

describe("GroupAdminPage", () => {
  it("lista os usuários com o papel atual", async () => {
    render(<GroupAdminPage />);
    expect(await screen.findByText("Ana")).toBeInTheDocument();
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("none");
    expect(screen.getByLabelText("Papel de Bia")).toHaveValue("teacher");
    expect(screen.getByText("Admin")).toBeInTheDocument();
  });

  it("filtra pela busca", async () => {
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Buscar por nome ou e-mail"), {target: {value: "bia"}});
    expect(screen.queryByText("Ana")).not.toBeInTheDocument();
    expect(screen.getByText("Bia")).toBeInTheDocument();
  });

  it("muda o papel e grava", async () => {
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "curator"}});
    await waitFor(() => expect(repo.setTeachingRole).toHaveBeenCalledWith("u1", "curator"));
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("curator");
  });

  it("se a gravação falha, volta ao papel anterior e avisa", async () => {
    repo.setTeachingRole.mockRejectedValue(new Error("permission-denied"));
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "teacher"}});
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Não foi possível salvar o papel de Ana. Tente novamente."
    );
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("none");
  });

  it("desabilita o select enquanto a gravação está em andamento", async () => {
    let resolve!: () => void;
    repo.setTeachingRole.mockReturnValue(new Promise<void>((r) => (resolve = r)));
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "curator"}});
    expect(screen.getByLabelText("Papel de Ana")).toBeDisabled();
    expect(screen.getByLabelText("Papel de Bia")).toBeEnabled();
    await act(async () => resolve());
    expect(screen.getByLabelText("Papel de Ana")).toBeEnabled();
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("curator");
  });

  it("reabilita o select com o papel anterior quando a gravação falha", async () => {
    let reject!: (e: Error) => void;
    repo.setTeachingRole.mockReturnValue(new Promise<void>((_, rj) => (reject = rj)));
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "teacher"}});
    expect(screen.getByLabelText("Papel de Ana")).toBeDisabled();
    await act(async () => reject(new Error("permission-denied")));
    expect(screen.getByLabelText("Papel de Ana")).toBeEnabled();
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("none");
    expect(screen.getByRole("alert")).toBeInTheDocument();
  });

  it("mostra erro quando a lista não carrega", async () => {
    repo.listMembers.mockRejectedValue(new Error("offline"));
    render(<GroupAdminPage />);
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar os usuários.");
  });
});
