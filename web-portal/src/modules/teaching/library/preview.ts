export function previewKind(
  contentType: string | undefined
): "pdf" | "image" | "other" {
  if (contentType === "application/pdf") return "pdf";
  if (contentType?.startsWith("image/")) return "image";
  return "other";
}
