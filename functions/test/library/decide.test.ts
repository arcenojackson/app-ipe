import {describe, expect, it} from "vitest";
import {
  decideDeletion,
  decidePublication,
  latestPerVoter,
} from "../../src/teaching/library/decide";
import {makeItem, vote} from "./fakes";

const item = makeItem({id: "i1", authorId: "author", version: 1});
const curators = new Set(["c1", "c2", "c3"]);
const approve = (id: string, voterId: string, createdAt = 1) =>
  vote({id, voterId, action: "approve", version: 1, createdAt});

describe("latestPerVoter", () => {
  it("mantém só o último voto de cada votante", () => {
    const result = latestPerVoter([
      vote({id: "a", voterId: "c1", action: "approve", createdAt: 1}),
      vote({id: "b", voterId: "c1", action: "reject", createdAt: 2}),
      vote({id: "c", voterId: "c2", action: "approve", createdAt: 1}),
    ]);
    expect(result.map((v) => [v.voterId, v.action]).sort()).toEqual([
      ["c1", "reject"],
      ["c2", "approve"],
    ]);
  });
});

describe("decidePublication", () => {
  it("2 aprovações de curadores distintos publicam", () => {
    const d = decidePublication(item, [approve("a", "c1"), approve("b", "c2")], curators);
    expect(d).toEqual({type: "publish", by: ["c1", "c2"]});
  });

  it("1 aprovação não publica", () => {
    expect(decidePublication(item, [approve("a", "c1")], curators)).toEqual({type: "none"});
  });

  it("o mesmo curador aprovando duas vezes conta uma vez", () => {
    const d = decidePublication(item, [approve("a", "c1", 1), approve("b", "c1", 2)], curators);
    expect(d).toEqual({type: "none"});
  });

  it("voto do autor, de não-curador e de versão antiga não conta", () => {
    const votes = [
      approve("a", "author"),
      approve("b", "alguem-sem-papel"),
      vote({id: "c", voterId: "c1", action: "approve", version: 0}),
      approve("d", "c2"),
    ];
    const withAuthorCurator = new Set([...curators, "author"]);
    expect(decidePublication(item, votes, withAuthorCurator)).toEqual({type: "none"});
  });

  it("o último voto do curador vale (aprovou e depois rejeitou)", () => {
    const votes = [
      approve("a", "c1", 1),
      vote({id: "b", voterId: "c1", action: "reject", version: 1, createdAt: 2, comment: "Não"}),
      approve("c", "c2", 3),
    ];
    expect(decidePublication(item, votes, curators)).toEqual({type: "none"});
  });

  it("1 curador devolvendo basta e tem prioridade", () => {
    const votes = [
      approve("a", "c1"),
      approve("b", "c2"),
      vote({id: "c", voterId: "c3", action: "return", version: 1, comment: "Falta a referência", createdAt: 5}),
    ];
    expect(decidePublication(item, votes, curators)).toEqual({
      type: "return", by: "c3", comment: "Falta a referência",
    });
  });

  it("2 rejeições distintas rejeitam; 1 não", () => {
    const reject = (id: string, voterId: string, comment: string) =>
      vote({id, voterId, action: "reject", version: 1, comment});
    expect(decidePublication(item, [reject("a", "c1", "Fora do escopo")], curators)).toEqual({type: "none"});
    expect(decidePublication(item, [reject("a", "c1", "Fora do escopo"), reject("b", "c2", "Duplicado")], curators)).toEqual({
      type: "reject", comments: ["Fora do escopo", "Duplicado"], by: ["c1", "c2"],
    });
  });
});

describe("decideDeletion", () => {
  const withRequest = makeItem({
    id: "d1", status: "published",
    deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1},
  });
  const approveDel = (id: string, voterId: string, requestId = "r1") =>
    vote({id, voterId, action: "delete_approve", requestId});

  it("sem pedido aberto não há decisão", () => {
    expect(decideDeletion(makeItem({id: "x"}), [approveDel("a", "c2")], curators)).toEqual({type: "none"});
  });

  it("2 aprovações de outros curadores executam", () => {
    const d = decideDeletion(withRequest, [approveDel("a", "c2"), approveDel("b", "c3")], curators);
    expect(d).toEqual({type: "execute", by: ["c2", "c3"]});
  });

  it("aprovação de quem pediu e votos de outro pedido não contam", () => {
    const votes = [approveDel("a", "c1"), approveDel("b", "c2"), approveDel("c", "c3", "velho")];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({type: "none"});
  });

  it("1 recusa encerra o pedido", () => {
    const votes = [
      approveDel("a", "c2"),
      vote({id: "b", voterId: "c3", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: 3}),
    ];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({
      type: "refuse", by: "c3", comment: "Ainda é usado",
    });
  });

  it("quem recusou e depois aprovou conta como aprovação (último voto)", () => {
    const votes = [
      vote({id: "a", voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Não", createdAt: 1}),
      vote({id: "b", voterId: "c2", action: "delete_approve", requestId: "r1", createdAt: 2}),
      approveDel("c", "c3"),
    ];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({type: "execute", by: ["c2", "c3"]});
  });
});
