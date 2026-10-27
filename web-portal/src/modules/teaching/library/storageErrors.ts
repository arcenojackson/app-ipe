const MESSAGES: Record<string, string> = {
  "storage/unauthorized": "Sem permissão para este arquivo.",
  "storage/object-not-found": "Arquivo não encontrado.",
};

export const SPECIFIC_FILE_ERRORS = Object.values(MESSAGES);

// Mensagem específica para os erros do Storage que o usuário entende; o resto
// cai no texto genérico. O código fica no console para diagnóstico.
export function fileErrorMessage(error: unknown, fallback: string): string {
  const code = (error as {code?: unknown} | null)?.code;
  console.error("Storage:", typeof code === "string" ? code : error);
  return (typeof code === "string" && MESSAGES[code]) || fallback;
}
