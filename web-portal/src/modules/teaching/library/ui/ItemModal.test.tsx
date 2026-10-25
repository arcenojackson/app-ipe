import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import type {Viewer} from "../types";
import {ItemModal} from "./ItemModal";

vi.mock("./ItemDetail", () => ({
  ItemDetail: ({itemId, onClose}: {itemId: string; onClose: () => void}) => (
    <div>
      detalhe {itemId}
      <button type="button" onClick={onClose}>Fechar</button>
    </div>
  ),
}));

const viewer: Viewer = {uid: "t1", isCurator: false, isAdmin: false};

describe("ItemModal", () => {
  it("é um diálogo que mostra o detalhe do item", () => {
    render(<ItemModal itemId="i1" viewer={viewer} onClose={() => undefined} />);
    expect(screen.getByRole("dialog", {name: "Detalhes do item"})).toHaveTextContent("detalhe i1");
  });

  it("fecha com Escape, clique no fundo e pelo botão do detalhe", () => {
    const onClose = vi.fn();
    const {container} = render(<ItemModal itemId="i1" viewer={viewer} onClose={onClose} />);
    fireEvent.keyDown(window, {key: "Escape"});
    expect(onClose).toHaveBeenCalledTimes(1);
    const backdrop = container.parentElement?.querySelector(".fixed") as HTMLElement;
    fireEvent.mouseDown(backdrop);
    expect(onClose).toHaveBeenCalledTimes(2);
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalledTimes(3);
  });
});
