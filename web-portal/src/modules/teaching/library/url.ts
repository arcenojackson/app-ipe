export function libraryUrl(params: {item?: string | null}): string {
  return params.item ?
    `/ensino?item=${encodeURIComponent(params.item)}` :
    "/ensino";
}

export function readParams(search: {get(name: string): string | null}): {
  item: string | null;
} {
  return {item: search.get("item") || null};
}
