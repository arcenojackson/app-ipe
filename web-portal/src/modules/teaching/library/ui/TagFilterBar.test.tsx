import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {EMPTY_TAGS, type Tag} from "../tags";
import {TagFilterBar} from "./TagFilterBar";

const tags: Tag[] = [
  {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
  {id: "assunto-trindade", kind: "subject", name: "Trindade", order: 1, active: true},
  {id: "assunto-velho", kind: "subject", name: "Assunto antigo", order: 2, active: false},
  {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
];

const base = {tags, value: EMPTY_TAGS, text: "", onChange: () => undefined, onTextChange: () => undefined};

describe("TagFilterBar", () => {
  it("marcar uma tag chama onChange com ela no campo certo", () => {
    const onChange = vi.fn();
    render(<TagFilterBar {...base} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", {name: /Assunto/}));
    fireEvent.click(screen.getByRole("checkbox", {name: "Trindade"}));
    expect(onChange).toHaveBeenCalledWith({...EMPTY_TAGS, subjectTags: ["assunto-trindade"]});
  });

  it("só oferece tags ativas nos menus", () => {
    render(<TagFilterBar {...base} />);
    fireEvent.click(screen.getByRole("button", {name: /Assunto/}));
    expect(screen.queryByRole("checkbox", {name: "Assunto antigo"})).not.toBeInTheDocument();
  });

  it("chips dos filtros ativos têm ✕ que remove a tag", () => {
    const onChange = vi.fn();
    render(<TagFilterBar {...base} value={{...EMPTY_TAGS, ageTags: ["faixa-ump"]}} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", {name: "Remover UMP"}));
    expect(onChange).toHaveBeenCalledWith(EMPTY_TAGS);
  });

  it("digitar na busca chama onTextChange", () => {
    const onTextChange = vi.fn();
    render(<TagFilterBar {...base} onTextChange={onTextChange} />);
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "fé"}});
    expect(onTextChange).toHaveBeenCalledWith("fé");
  });

  it("o menu fecha ao clicar fora e com Esc; abrir outro tipo fecha o anterior", () => {
    render(<TagFilterBar {...base} />);
    fireEvent.click(screen.getByRole("button", {name: /Assunto/}));
    expect(screen.getByRole("checkbox", {name: "Trindade"})).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: /Faixa/}));
    expect(screen.queryByRole("checkbox", {name: "Trindade"})).not.toBeInTheDocument();
    expect(screen.getByRole("checkbox", {name: "UMP"})).toBeInTheDocument();
    fireEvent.mouseDown(document.body);
    expect(screen.queryByRole("checkbox", {name: "UMP"})).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: /Tipo/}));
    fireEvent.keyDown(document, {key: "Escape"});
    expect(screen.queryByRole("checkbox", {name: "Artigos"})).not.toBeInTheDocument();
  });
});
