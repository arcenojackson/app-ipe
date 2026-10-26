import {describe, expect, it} from "vitest";
import {MAX_TOKEN_LENGTH, MAX_TOKENS, searchTokens} from "./searchTokens";

describe("searchTokens", () => {
  it("gera prefixos de 2 letras em diante, sem acento nem maiúsculas", () => {
    expect(searchTokens("Fé")).toEqual(["fe"]);
    expect(searchTokens("Trindade")).toEqual([
      "tr", "tri", "trin", "trind", "trinda", "trindad", "trindade",
    ]);
  });

  it("palavra de 1 caractere é ignorada", () => {
    expect(searchTokens("A")).toEqual([]);
    expect(searchTokens("A fé")).toEqual(["fe"]);
  });

  it("acentos: o token é sem acento", () => {
    const tokens = searchTokens("Santificação");
    expect(tokens).toContain("santificacao");
    expect(tokens).toContain("sa");
    expect(tokens).not.toContain("santificação");
  });

  it("separa palavras por pontuação e junta os prefixos de todas", () => {
    const tokens = searchTokens("Bíblia: autoridade");
    expect(tokens).toContain("biblia");
    expect(tokens).toContain("autoridade");
  });

  it("palavra longa gera prefixos só até 20 caracteres", () => {
    const tokens = searchTokens("a".repeat(30));
    expect(Math.max(...tokens.map((t) => t.length))).toBe(MAX_TOKEN_LENGTH);
    expect(MAX_TOKEN_LENGTH).toBe(20);
  });

  it("sem repetições e nunca passa de 150 tokens", () => {
    expect(searchTokens("fé fé fé")).toEqual(["fe"]);
    const many = Array.from({length: 40}, (_, i) => `palavra${i}longa`).join(" ");
    const tokens = searchTokens(many);
    expect(tokens.length).toBeLessThanOrEqual(MAX_TOKENS);
    expect(new Set(tokens).size).toBe(tokens.length);
  });
});
