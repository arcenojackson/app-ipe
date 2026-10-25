import {normalizeText} from "./text";

export const MAX_TOKEN_LENGTH = 20;
export const MAX_TOKENS = 150;

// Palavras de 1 caractere não entram (nem na busca: ver planQuery).
export function searchWords(text: string): string[] {
  return normalizeText(text)
    .split(/[^\p{L}\p{N}]+/u)
    .filter((word) => word.length >= 2);
}

// Prefixos (2 a 20 letras) de cada palavra do nome, sem acento nem caixa.
// Gravados em `searchTokens` para a busca por prefixo com array-contains.
export function searchTokens(text: string): string[] {
  const tokens = new Set<string>();
  for (const word of searchWords(text)) {
    const longest = Math.min(word.length, MAX_TOKEN_LENGTH);
    for (let length = 2; length <= longest; length++) {
      if (tokens.size >= MAX_TOKENS) return [...tokens];
      tokens.add(word.slice(0, length));
    }
  }
  return [...tokens];
}
