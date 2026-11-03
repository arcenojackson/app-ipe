import {describe, expect, it} from "vitest";
import {loginPathFor, safeNextPath} from "./redirect";

describe("loginPathFor", () => {
  it("guarda o destino original", () => {
    expect(loginPathFor("/eleicoes/abc")).toBe("/login?next=%2Feleicoes%2Fabc");
  });

  it("não guarda destino para a raiz nem para o próprio login", () => {
    expect(loginPathFor("/")).toBe("/login");
    expect(loginPathFor("/login")).toBe("/login");
  });
});

describe("safeNextPath", () => {
  it("aceita caminhos internos", () => {
    expect(safeNextPath("/eleicoes/abc")).toBe("/eleicoes/abc");
    expect(safeNextPath("/ensino/forum?x=1")).toBe("/ensino/forum?x=1");
  });

  it("cai na raiz quando falta ou é inválido", () => {
    expect(safeNextPath(null)).toBe("/");
    expect(safeNextPath("")).toBe("/");
    expect(safeNextPath("/login")).toBe("/");
  });

  it("recusa destinos externos (open redirect)", () => {
    expect(safeNextPath("https://evil.com")).toBe("/");
    expect(safeNextPath("//evil.com")).toBe("/");
    expect(safeNextPath("/\\evil.com")).toBe("/");
    expect(safeNextPath("javascript:alert(1)")).toBe("/");
  });
});
