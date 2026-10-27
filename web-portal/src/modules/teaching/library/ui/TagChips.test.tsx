import {render, screen} from "@testing-library/react";
import {describe, expect, it} from "vitest";
import type {Tag} from "../tags";
import {TagChips} from "./TagChips";

const byId = new Map<string, Tag>([
  ["a", {id: "a", kind: "type", name: "Artigos", order: 1, active: true}],
  ["b", {id: "b", kind: "age", name: "UMP", order: 1, active: true}],
]);

describe("TagChips", () => {
  it("mostra os nomes na ordem recebida", () => {
    render(<TagChips ids={["b", "a"]} byId={byId} />);
    const chips = screen.getAllByRole("listitem").map((el) => el.textContent);
    expect(chips).toEqual(["UMP", "Artigos"]);
  });

  it("id desconhecido aparece como Tag removida", () => {
    render(<TagChips ids={["a", "sumiu"]} byId={byId} />);
    expect(screen.getByText("Tag removida")).toBeInTheDocument();
  });
});
