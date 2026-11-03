import {describe, expect, it} from "vitest";
import {
  buildOpenMessage,
  invitePaths,
  isOpening,
} from "../src/elections/invites";

describe("isOpening", () => {
  it("só a transição rascunho → aberta conta", () => {
    expect(isOpening({status: "draft"}, {status: "open"})).toBe(true);
  });

  it("outras mudanças não são abertura", () => {
    expect(isOpening({status: "open"}, {status: "open"})).toBe(false);
    expect(isOpening({status: "open"}, {status: "closed"})).toBe(false);
    expect(isOpening({status: "draft"}, {status: "draft"})).toBe(false);
    expect(isOpening({status: "draft"}, {status: "closed"})).toBe(false);
  });

  it("documento ausente nunca é abertura", () => {
    expect(isOpening(undefined, {status: "open"})).toBe(false);
    expect(isOpening({status: "draft"}, undefined)).toBe(false);
    expect(isOpening(undefined, undefined)).toBe(false);
  });
});

describe("buildOpenMessage", () => {
  const message = buildOpenMessage("Eleição UMP 2026", "e1", ["t1", "t2"]);

  it("leva o tipo e o id da eleição para o app abrir a votação", () => {
    expect(message.data).toEqual({type: "election_open", electionId: "e1"});
    expect(message.tokens).toEqual(["t1", "t2"]);
  });

  it("texto autossuficiente, também para quem tem app antigo", () => {
    expect(message.notification?.title).toBe("Eleição aberta");
    expect(message.notification?.body).toBe(
      "Eleição UMP 2026. Abra o app para votar; " +
        "se não abrir a votação, atualize o app."
    );
  });

  it("prioridade alta no Android e som no iOS", () => {
    expect(message.android?.priority).toBe("high");
    expect(message.apns?.payload?.aps.sound).toBe("default");
  });
});

describe("invitePaths", () => {
  it("um convite por membro, no caminho em que o balão o lê", () => {
    expect(invitePaths("e1", ["a", "b"])).toEqual([
      "users/a/election_invites/e1",
      "users/b/election_invites/e1",
    ]);
  });

  it("sem membros, sem caminhos", () => {
    expect(invitePaths("e1", [])).toEqual([]);
  });
});
