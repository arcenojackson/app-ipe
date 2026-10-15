const KEYS: Record<string, string> = {
  presidente: "presidente",
  vice: "vice",
  secretario: "secretario(a)",
  tesoureiro: "tesoureiro(a)",
};

// Chave de `societies.board` (mesma que o app grava: label em minúsculas).
export const boardKey = (position: string): string => {
  const key = KEYS[position];
  if (!key) throw new Error(`Cargo desconhecido: ${position}`);
  return key;
};

// Aplica os vencedores sobre a diretoria atual, só nos cargos eleitos.
// Board em formato antigo (lista) é descartado; chaves do mesmo cargo em
// outra caixa são removidas para não duplicar o cargo.
export const applyWinners = (
  currentBoard: unknown,
  winners: Record<string, string>
): Record<string, string[]> => {
  const next: Record<string, string[]> = {};
  if (
    currentBoard &&
    typeof currentBoard === "object" &&
    !Array.isArray(currentBoard)
  ) {
    for (const [key, value] of Object.entries(currentBoard)) {
      if (Array.isArray(value)) next[key] = value.map(String);
      else if (typeof value === "string") next[key] = [value];
    }
  }
  for (const [position, userId] of Object.entries(winners)) {
    const key = boardKey(position);
    for (const existing of Object.keys(next)) {
      const lower = existing.toLowerCase();
      if (lower === key || lower === position) delete next[existing];
    }
    next[key] = [userId];
  }
  return next;
};
