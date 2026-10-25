export function normalizeText(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

// Ordem natural em pt-BR: sem diferenciar acento/maiúscula; "Aula 2" < "Aula 10".
export function compareNames(a: string, b: string): number {
  return a.localeCompare(b, "pt-BR", {sensitivity: "base", numeric: true});
}
