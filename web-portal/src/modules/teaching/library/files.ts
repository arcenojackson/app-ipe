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
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  gif: "image/gif",
  webp: "image/webp",
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
  // Sem a flag `i`: a regra do Firestore (`matches('https?://.+')`) diferencia maiúsculas.
  if (!/^https?:\/\/.+/.test(trimmed)) {
    return "Use um endereço que comece com http:// ou https://.";
  }
  return null;
}

export function validateDescription(description: string): string | null {
  if (description.length > 1000) {
    return "A descrição pode ter no máximo 1000 caracteres.";
  }
  return null;
}

function isAllowedType(type: string): boolean {
  return type.startsWith("image/") || ALLOWED_TYPES.has(type);
}

// Alguns navegadores entregam `type` vazio ou genérico (ex.: octet-stream
// para .docx no Windows): se o tipo não é permitido, usa a extensão.
export function contentTypeFor(file: {name: string; type: string}): string {
  if (file.type && isAllowedType(file.type)) return file.type;
  const dot = file.name.lastIndexOf(".");
  const extension = dot >= 0 ? file.name.slice(dot + 1).toLowerCase() : "";
  return Object.hasOwn(EXTENSION_TYPES, extension) ? EXTENSION_TYPES[extension] : file.type;
}

export function validateFile(file: {
  name: string;
  size: number;
  type: string;
}): string | null {
  if (file.size <= 0) return "O arquivo está vazio.";
  if (file.size > MAX_FILE_BYTES) return "O arquivo passa de 100 MB.";
  const safeName = safeFileName(file.name);
  if (safeName.length === 0) return "O nome do arquivo é inválido.";
  if (safeName.length > 200) {
    return "O nome do arquivo é muito longo.";
  }
  if (!isAllowedType(contentTypeFor(file))) return "Tipo de arquivo não permitido. Use PDF, Office ou imagem.";
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
