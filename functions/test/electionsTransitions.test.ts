import {describe, expect, it} from "vitest";
import {isDue, nextTermStart} from "../src/elections/transitions";

// 00:00 de 01/01 em São Paulo (UTC-3) é 03:00 UTC.
const jan1 = (year: number) => new Date(Date.UTC(year, 0, 1, 3, 0));

describe("nextTermStart", () => {
  it("eleição em outubro, novembro ou dezembro vale a partir do 01/01 seguinte", () => {
    expect(nextTermStart(new Date("2026-10-27T15:00:00Z"))).toEqual(jan1(2027));
    expect(nextTermStart(new Date("2026-12-15T12:00:00Z"))).toEqual(jan1(2027));
  });

  it("usa o ano de São Paulo: 23h de 31/12 em SP ainda é o ano que termina", () => {
    // 31/12/2026 23:30 em SP = 01/01/2027 02:30 UTC.
    expect(nextTermStart(new Date("2027-01-01T02:30:00Z"))).toEqual(jan1(2027));
  });

  it("logo depois da virada em SP, o próximo mandato é o do ano seguinte", () => {
    expect(nextTermStart(new Date("2027-01-01T03:00:00Z"))).toEqual(jan1(2028));
  });
});

describe("isDue", () => {
  it("vencido a partir do instante de vigência, não antes", () => {
    const at = jan1(2027);
    expect(isDue(at, new Date("2027-01-01T02:59:59Z"))).toBe(false);
    expect(isDue(at, new Date("2027-01-01T03:00:00Z"))).toBe(true);
  });

  it("a rotina de 01/01 ao meio-dia em SP (15:00 UTC) já encontra vencido", () => {
    expect(isDue(jan1(2027), new Date("2027-01-01T15:00:00Z"))).toBe(true);
  });
});
