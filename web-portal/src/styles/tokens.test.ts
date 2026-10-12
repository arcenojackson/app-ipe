import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, expect, it} from "vitest";

const css = readFileSync(resolve(import.meta.dirname, "tokens.css"), "utf8");
const dart = readFileSync(
  resolve(import.meta.dirname, "../../../lib/src/shared/theme/app_theme.dart"),
  "utf8"
);

function cssHex(name: string): string {
  const match = css.match(new RegExp(`${name}:\\s*(#[0-9a-fA-F]{6})`));
  if (!match) throw new Error(`Token ${name} não encontrado em tokens.css`);
  return match[1].toLowerCase();
}

function dartHex(pattern: RegExp): string {
  const match = dart.match(pattern);
  if (!match) throw new Error(`Cor não encontrada em app_theme.dart: ${pattern}`);
  return `#${match[1].toLowerCase()}`;
}

const hex = "([0-9A-Fa-f]{6})";
const cases: [string, RegExp][] = [
  ["--ipe-primary", new RegExp(`const primary = Color\\(0xFF${hex}\\)`)],
  ["--ipe-background", new RegExp(`const background = Color\\(0xFF${hex}\\)`)],
  ["--ipe-surface", new RegExp(`const surface = Color\\(0xFF${hex}\\)`)],
  ["--ipe-surface-elevated", new RegExp(`const surfaceElevated = Color\\(0xFF${hex}\\)`)],
  ["--ipe-secondary", new RegExp(`secondary: Color\\(0xFF${hex}\\)`)],
  ["--ipe-error", new RegExp(`error: Color\\(0xFF${hex}\\)`)],
];

describe("design tokens do portal", () => {
  it.each(cases)("%s coincide com app_theme.dart", (token, pattern) => {
    expect(cssHex(token)).toBe(dartHex(pattern));
  });
});
