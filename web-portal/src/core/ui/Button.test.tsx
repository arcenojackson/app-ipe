import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {Button} from "./Button";

describe("Button", () => {
  it("dispara onClick", () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Salvar</Button>);
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("não dispara quando desabilitado", () => {
    const onClick = vi.fn();
    render(<Button disabled onClick={onClick}>Salvar</Button>);
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    expect(onClick).not.toHaveBeenCalled();
  });

  it("variante primária usa os tokens do app", () => {
    render(<Button>Entrar</Button>);
    const button = screen.getByRole("button", {name: "Entrar"});
    expect(button.className).toContain("bg-primary");
    expect(button.className).toContain("rounded-button");
  });

  it("em loading mostra o spinner, fica ocupado e não dispara", () => {
    const onClick = vi.fn();
    render(<Button loading onClick={onClick}>Salvar</Button>);
    const button = screen.getByRole("button", {name: "Salvar"});
    expect(button).toBeDisabled();
    expect(button).toHaveAttribute("aria-busy", "true");
    expect(button.querySelector("svg.animate-spin")).not.toBeNull();
    fireEvent.click(button);
    expect(onClick).not.toHaveBeenCalled();
  });
});
