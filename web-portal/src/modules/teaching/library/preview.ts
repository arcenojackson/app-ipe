const DOCX_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

// Acima disso o arquivo não é baixado para visualizar (só informações e Baixar).
export const MAX_INLINE_PREVIEW_BYTES = 50 * 1024 * 1024;

export type PreviewKind = "pdf" | "image" | "docx" | "other";

export function previewKind(contentType: string | undefined, fileName?: string): PreviewKind {
  if (contentType === "application/pdf") return "pdf";
  if (contentType?.startsWith("image/")) return "image";
  if (contentType === DOCX_TYPE || /\.docx$/i.test(fileName ?? "")) return "docx";
  return "other";
}
