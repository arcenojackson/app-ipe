export const MAX_FILE_BYTES = 100 * 1024 * 1024;
export const REQUIRED_APPROVALS = 2;

const EXTENSION_TYPES: Record<string, string> = {
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ppt: "application/vnd.ms-powerpoint",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  xls: "application/vnd.ms-excel",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  odt: "application/vnd.oasis.opendocument.text",
  odp: "application/vnd.oasis.opendocument.presentation",
  ods: "application/vnd.oasis.opendocument.spreadsheet",
};

const ALLOWED_TYPES = new Set(Object.values(EXTENSION_TYPES));

export function validateName(name: string): string | null {
  const trimmed = name.trim();
  if (trimmed.length === 0) return "Informe um nome.";
  if (trimmed.length > 120) return "O nome pode ter no máximo 120 caracteres.";
  return null;
}

export function validateUrl(url: string): string | null {
  const trimmed = url.trim();
  if (trimmed.length === 0) return "Informe o endereço do link.";
  if (trimmed.length > 2000) return "O endereço é muito longo.";
  if (!/^https?:\/\/.+/i.test(trimmed)) {
    return "Use um endereço que comece com http:// ou https://.";
  }
  return null;
}

// Alguns navegadores entregam `type` vazio para Office: usa a extensão.
export function contentTypeFor(file: {name: string; type: string}): string {
  if (file.type) return file.type;
  const extension = file.name.split(".").pop()?.toLowerCase() ?? "";
  return EXTENSION_TYPES[extension] ?? "";
}

export function validateFile(file: {
  name: string;
  size: number;
  type: string;
}): string | null {
  if (file.size <= 0) return "O arquivo está vazio.";
  if (file.size > MAX_FILE_BYTES) return "O arquivo passa de 100 MB.";
  if (safeFileName(file.name).length > 200) {
    return "O nome do arquivo é muito longo.";
  }
  const type = contentTypeFor(file);
  const allowed = type.startsWith("image/") || ALLOWED_TYPES.has(type);
  if (!allowed) return "Tipo de arquivo não permitido. Use PDF, Office ou imagem.";
  return null;
}

export function safeFileName(name: string): string {
  return name.trim().replace(/[/\\]/g, "_");
}

export function storagePathFor(
  itemId: string,
  version: number,
  fileName: string
): string {
  return `teaching/materials/${itemId}/v${version}-${safeFileName(fileName)}`;
}
