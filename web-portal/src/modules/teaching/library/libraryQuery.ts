import {MAX_TOKEN_LENGTH, searchWords} from "./searchTokens";
import {normalizeText} from "./text";
import type {LibraryItem} from "./types";

export interface LibraryFilters {
  typeTags: string[];
  subjectTags: string[];
  ageTags: string[];
  text: string;
}

export const EMPTY_FILTERS: LibraryFilters = {typeTags: [], subjectTags: [], ageTags: [], text: ""};

export type ServerFilter = {
  field: "searchTokens" | "subjectTags" | "typeTags" | "ageTags";
  op: "array-contains" | "array-contains-any";
  values: string[];
} | null;

const overlaps = (selected: string[], ids: string[] | undefined) =>
  selected.length === 0 || (ids ?? []).some((id) => selected.includes(id));

// O Firestore só aceita um filtro de array por consulta. O servidor aplica o
// mais seletivo (texto > assunto > tipo > faixa) e o cliente reaplica todos.
// Dentro de um tipo de tag vale "ou"; entre tipos e texto vale "e".
export function planQuery(f: LibraryFilters): {
  server: ServerFilter;
  matches(item: LibraryItem): boolean;
} {
  const words = searchWords(f.text);
  let server: ServerFilter = null;
  if (words.length > 0) {
    const longest = words.reduce((a, b) => (b.length > a.length ? b : a));
    server = {
      field: "searchTokens",
      op: "array-contains",
      values: [longest.slice(0, MAX_TOKEN_LENGTH)],
    };
  } else if (f.subjectTags.length > 0) {
    server = {field: "subjectTags", op: "array-contains-any", values: f.subjectTags};
  } else if (f.typeTags.length > 0) {
    server = {field: "typeTags", op: "array-contains-any", values: f.typeTags};
  } else if (f.ageTags.length > 0) {
    server = {field: "ageTags", op: "array-contains-any", values: f.ageTags};
  }

  return {
    server,
    matches(item) {
      const name = normalizeText(item.name);
      return (
        words.every((word) => name.includes(word)) &&
        overlaps(f.typeTags, item.typeTags) &&
        overlaps(f.subjectTags, item.subjectTags) &&
        overlaps(f.ageTags, item.ageTags)
      );
    },
  };
}

export interface Batch<C> {
  items: Array<{item: LibraryItem; cursor: C}>;
  // O servidor não tem mais documentos depois deste lote.
  exhausted: boolean;
}

export const FETCH_BATCH_SIZE = 50;
export const MAX_BATCHES_PER_PAGE = 10;

// Enche uma página varrendo lotes do servidor e filtrando no cliente. Para ao
// encher a página, ao esgotar o servidor ou após MAX_BATCHES_PER_PAGE lotes
// (devolve o que achou e deixa "Carregar mais" continuar de onde parou).
export async function collectPage<C>(
  fetch: (after: C | null, size: number) => Promise<Batch<C>>,
  matches: (item: LibraryItem) => boolean,
  after: C | null,
  pageSize: number
): Promise<{items: LibraryItem[]; cursor: C | null; done: boolean}> {
  const kept: Array<{item: LibraryItem; cursor: C}> = [];
  let scanned: C | null = after;
  let exhausted = false;

  for (let batches = 0; batches < MAX_BATCHES_PER_PAGE; batches++) {
    const batch = await fetch(scanned, FETCH_BATCH_SIZE);
    for (const entry of batch.items) {
      scanned = entry.cursor;
      if (matches(entry.item)) kept.push(entry);
    }
    exhausted = batch.exhausted;
    if (kept.length >= pageSize || exhausted) break;
  }

  const truncated = kept.length > pageSize;
  const page = kept.slice(0, pageSize);
  // Cortou a página: continua logo depois do último item devolvido. Senão tudo
  // o que foi varrido já foi consumido: continua do último documento varrido
  // (usar o último devolvido repetiria a varredura sem avançar).
  const cursor = truncated ? page[page.length - 1].cursor : scanned;
  return {
    items: page.map((entry) => entry.item),
    cursor: cursor === after && page.length === 0 && exhausted ? null : cursor,
    done: exhausted && !truncated,
  };
}
