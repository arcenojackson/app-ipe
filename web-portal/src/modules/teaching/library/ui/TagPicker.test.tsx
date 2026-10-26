import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {EMPTY_TAGS, type Tag} from "../tags";
import {TagPicker} from "./TagPicker";

const tags: Tag[] = [
  {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
  {id: "assunto-trindade", kind: "subject", name: "Trindade", order: 1, active: true},
  {id: "assunto-velho", kind: "subject", name: "Assunto antigo", order: 2, active: false},
  {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
];

describe("TagPicker", () => {
  it("lista só as tags ativas, em três grupos", () => {
    render(<TagPicker tags={tags} value={EMPTY_TAGS} onChange={() => undefined} />);
    expect(screen.getByRole("group", {name: "Tipo"})).toBeInTheDocument();
    expect(screen.getByRole("group", {name: "Assunto"})).toBeInTheDocument();
    expect(screen.getByRole("group", {name: "Faixa"})).toBeInTheDocument();
    expect(screen.getByRole("checkbox", {name: "Trindade"})).toBeInTheDocument();
    expect(screen.queryByRole("checkbox", {name: "Assunto antigo"})).not.toBeInTheDocument();
  });

  it("marcar acrescenta o id no campo certo; desmarcar remove", () => {
    const onChange = vi.fn();
    const {rerender} = render(<TagPicker tags={tags} value={EMPTY_TAGS} onChange={onChange} />);
    fireEvent.click(screen.getByRole("checkbox", {name: "Trindade"}));
    expect(onChange).toHaveBeenCalledWith({...EMPTY_TAGS, subjectTags: ["assunto-trindade"]});

    const value = {...EMPTY_TAGS, subjectTags: ["assunto-trindade"]};
    rerender(<TagPicker tags={tags} value={value} onChange={onChange} />);
    expect(screen.getByRole("checkbox", {name: "Trindade"})).toBeChecked();
    fireEvent.click(screen.getByRole("checkbox", {name: "Trindade"}));
    expect(onChange).toHaveBeenLastCalledWith(EMPTY_TAGS);
  });

  it("mostra o erro em role=alert", () => {
    render(
      <TagPicker tags={tags} value={EMPTY_TAGS} onChange={() => undefined} error="Escolha pelo menos uma tag de tipo." />
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Escolha pelo menos uma tag de tipo.");
  });
});
