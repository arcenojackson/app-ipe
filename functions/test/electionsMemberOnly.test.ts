import {describe, expect, it} from "vitest";
import {assertMemberAllowed} from "../src/elections/voters";

describe("assertMemberAllowed", () => {
  it("memberOnly recusa quem não é da sociedade, com mensagem clara", () => {
    expect(() => assertMemberAllowed(true, false)).toThrowError(
      expect.objectContaining({
        code: "permission-denied",
        message: "A votação é só para membros da sociedade.",
      })
    );
  });

  it("memberOnly deixa o membro entrar", () => {
    expect(() => assertMemberAllowed(true, true)).not.toThrow();
  });

  it("sem memberOnly não recusa ninguém (comportamento da web)", () => {
    expect(() => assertMemberAllowed(false, false)).not.toThrow();
    expect(() => assertMemberAllowed(false, true)).not.toThrow();
  });
});
