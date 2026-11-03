import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {Modal} from "./Modal";

describe("Modal", () => {
  it("é um diálogo com título e conteúdo, e o foco vai para o botão Fechar", () => {
    render(<Modal title="Presentes (2)" onClose={() => {}}><p>conteúdo</p></Modal>);
    const dialog = screen.getByRole("dialog", {name: "Presentes (2)"});
    expect(dialog).toHaveAttribute("aria-modal", "true");
    expect(dialog).toHaveTextContent("conteúdo");
    expect(screen.getByRole("button", {name: "Fechar"})).toHaveFocus();
  });

  it("fecha pelo botão, com Esc e ao clicar fora, mas não ao clicar dentro", () => {
    const onClose = vi.fn();
    render(<Modal title="T" onClose={onClose}><p>dentro</p></Modal>);

    fireEvent.click(screen.getByText("dentro"));
    expect(onClose).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    fireEvent.keyDown(document, {key: "Escape"});
    fireEvent.click(screen.getByTestId("modal-backdrop"));
    expect(onClose).toHaveBeenCalledTimes(3);
  });
});
