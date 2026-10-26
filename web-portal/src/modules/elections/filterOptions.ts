import type {Candidate} from "./types";

const normalize = (text: string): string =>
  text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();

/** Filtra por nome, sem diferenciar maiúsculas nem acentos; mantém a ordem. */
export function filterOptions(options: Candidate[], query: string): Candidate[] {
  const q = normalize(query);
  if (q === "") return options;
  return options.filter((o) => normalize(o.name).includes(q));
}
