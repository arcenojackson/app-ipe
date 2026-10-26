import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Round} from "../types";
import {BallotStep} from "./BallotStep";

const round = (number: 1 | 2 | 3, position = "presidente"): Round => ({
  id: "r1",
  position,
  number,
  options: [
    {id: "a", name: "Ana Souza"},
    {id: "b", name: "João Silva"},
    {id: "c", name: "Maria Conceição"},
  ],
});

const setup = (r: Round, onSubmit = vi.fn()) => {
  render(<BallotStep round={r} busy={false} error={null} onSubmit={onSubmit} />);
  return onSubmit;
};

describe("BallotStep", () => {
  it("título com o cargo e o número do escrutínio", () => {
    setup(round(2, "secretario2"));
    expect(screen.getByText("Votação para 2º Secretário(a) — 2º escrutínio")).toBeInTheDocument();
  });

  it("1º escrutínio tem busca por nome que filtra as opções; Branco sempre aparece", () => {
    setup(round(1));
    const search = screen.getByLabelText("Buscar por nome");
    fireEvent.change(search, {target: {value: "joao"}});
    expect(screen.getByLabelText("João Silva")).toBeInTheDocument();
    expect(screen.queryByLabelText("Ana Souza")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Branco")).toBeInTheDocument();
  });

  it("2º e 3º escrutínios não têm busca", () => {
    setup(round(2));
    expect(screen.queryByLabelText("Buscar por nome")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Ana Souza")).toBeInTheDocument();
    expect(screen.getByLabelText("Branco")).toBeInTheDocument();
  });

  it("a escolha feita continua valendo depois de filtrar a lista", () => {
    const onSubmit = setup(round(1));
    fireEvent.click(screen.getByLabelText("Ana Souza"));
    fireEvent.change(screen.getByLabelText("Buscar por nome"), {target: {value: "joao"}});
    fireEvent.click(screen.getByRole("button", {name: "Confirmar voto"}));
    expect(onSubmit).toHaveBeenCalledWith("a");
  });

  it("Confirmar voto só habilita com escolha e envia o id (ou blank)", () => {
    const onSubmit = setup(round(3));
    const confirm = screen.getByRole("button", {name: "Confirmar voto"});
    expect(confirm).toBeDisabled();
    fireEvent.click(screen.getByLabelText("Branco"));
    expect(confirm).toBeEnabled();
    fireEvent.click(confirm);
    expect(onSubmit).toHaveBeenCalledWith("blank");
  });
});
