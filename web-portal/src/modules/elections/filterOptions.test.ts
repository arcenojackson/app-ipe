import {describe, expect, it} from "vitest";
import {filterOptions} from "./filterOptions";

const options = [
  {id: "1", name: "João Silva"},
  {id: "2", name: "Maria Conceição"},
  {id: "3", name: "Ana Souza"},
];

describe("filterOptions", () => {
  it("ignora acentos e maiúsculas", () => {
    expect(filterOptions(options, "joao")).toEqual([options[0]]);
    expect(filterOptions(options, "CONCEICAO")).toEqual([options[1]]);
  });

  it("acha em qualquer parte do nome", () => {
    expect(filterOptions(options, "sou")).toEqual([options[2]]);
  });

  it("consulta vazia ou só espaços devolve tudo, na mesma ordem", () => {
    expect(filterOptions(options, "")).toEqual(options);
    expect(filterOptions(options, "   ")).toEqual(options);
  });

  it("sem correspondência devolve lista vazia", () => {
    expect(filterOptions(options, "zzz")).toEqual([]);
  });
});
