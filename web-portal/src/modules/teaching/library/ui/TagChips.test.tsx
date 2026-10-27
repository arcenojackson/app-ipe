import {render, screen} from "@testing-library/react";
import {describe, expect, it} from "vitest";
import type {Tag} from "../tags";
import {CompactTagChips, TagChips} from "./TagChips";

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

describe("CompactTagChips", () => {
  const many = new Map<string, Tag>(
    ["t1", "t2", "t3", "t4", "t5"].map((id, n) => [id, {id, kind: "subject", name: `Tag ${n + 1}`, order: n, active: true}])
  );

  it("mostra até 3 chips e '+N' com todos os nomes no title", () => {
    render(<CompactTagChips ids={["t1", "t2", "t3", "t4", "t5"]} byId={many} />);
    expect(screen.getAllByRole("listitem").map((el) => el.textContent)).toEqual(["Tag 1", "Tag 2", "Tag 3", "+2"]);
    expect(screen.getByText("+2")).toHaveAttribute("title", "Tag 1, Tag 2, Tag 3, Tag 4, Tag 5");
  });

  it("até 3 tags não mostra '+N'", () => {
    render(<CompactTagChips ids={["t1", "t2"]} byId={many} />);
    expect(screen.getAllByRole("listitem")).toHaveLength(2);
  });
});
