import {render, screen, within} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Cargo, ConductRound} from "../types";
import {CargoCard, cargoKey} from "./CargoCard";

const idle: Cargo = {
  position: "presidente", stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null,
};

const closedRound = (number: 1 | 2): ConductRound => ({
  id: "r1",
  position: "presidente",
  number,
  cycle: 1,
  status: "closed",
  options: [
    {id: "a", name: "Ana"},
    {id: "b", name: "Bia"},
    {id: "c", name: "Caio"},
  ],
  votedCount: 3,
  result: {
    counts: {a: 2, b: 1},
    blank: 0,
    total: 3,
    presentCount: 3,
    threshold: 2,
    winnerId: null,
    tie: [],
    divergence: false,
  },
});

const base = {
  approved: [],
  votedIds: [],
  busy: false,
  roundOpenElsewhere: false,
  pending: null,
  onAction: vi.fn(),
  openRound: null,
};

describe("CargoCard", () => {
  it("com escrutínio aberto em outro cargo, desabilita as ações", () => {
    render(<CargoCard {...base} cargo={idle} lastClosed={null} roundOpenElsewhere />);
    expect(screen.getByRole("button", {name: "Iniciar 1º escrutínio"})).toBeDisabled();
  });

  it("sem escrutínio aberto, a ação fica habilitada", () => {
    render(<CargoCard {...base} cargo={idle} lastClosed={null} />);
    expect(screen.getByRole("button", {name: "Iniciar 1º escrutínio"})).toBeEnabled();
  });

  it("só o botão da ação em andamento mostra o spinner", () => {
    render(
      <CargoCard
        {...base}
        cargo={idle}
        lastClosed={null}
        busy
        pending={cargoKey("presidente", "start")}
      />
    );
    const button = screen.getByRole("button", {name: "Iniciar 1º escrutínio"});
    expect(button).toHaveAttribute("aria-busy", "true");
  });

  it("no 1º escrutínio o resultado omite quem teve 0 voto", () => {
    render(
      <CargoCard
        {...base}
        cargo={{...idle, stage: "confirming"}}
        lastClosed={closedRound(1)}
      />
    );
    const result = screen.getByText("Resultado do 1º escrutínio").parentElement!;
    expect(within(result).getByText("Ana: 2")).toBeInTheDocument();
    expect(within(result).getByText("Bia: 1")).toBeInTheDocument();
    expect(within(result).queryByText(/Caio/)).toBeNull();
    expect(within(result).getByText("Branco: 0")).toBeInTheDocument();
  });

  it("no 2º escrutínio todas as opções continuam no resultado", () => {
    render(
      <CargoCard
        {...base}
        cargo={{...idle, stage: "awaiting3"}}
        lastClosed={closedRound(2)}
      />
    );
    expect(screen.getByText("Caio: 0")).toBeInTheDocument();
  });
});
