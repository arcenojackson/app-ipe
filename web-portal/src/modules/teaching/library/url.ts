export function libraryUrl(params: {
  pasta?: string | null;
  item?: string | null;
}): string {
  const parts: string[] = [];
  if (params.pasta) parts.push(`pasta=${encodeURIComponent(params.pasta)}`);
  if (params.item) parts.push(`item=${encodeURIComponent(params.item)}`);
  return parts.length > 0 ?
    `/ensino/biblioteca?${parts.join("&")}` :
    "/ensino/biblioteca";
}

export function readParams(search: {get(name: string): string | null}): {
  pasta: string | null;
  item: string | null;
} {
  return {pasta: search.get("pasta") || null, item: search.get("item") || null};
}
