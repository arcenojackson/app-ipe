import {MAX_TOKEN_LENGTH, searchWords} from "../library/searchTokens";

export interface TopicFilters {
  tagId?: string | null;
  search?: string;
}

export interface TopicQuerySpec {
  tagId: string | null;
  token: string | null;
  words: string[];
}

// O Firestore só aceita um array-contains por consulta: assunto e busca são
// exclusivos. A busca consulta a palavra mais longa (prefixo em searchTokens)
// e o cliente confere todas as palavras no título.
export function topicQuery({tagId, search}: TopicFilters): TopicQuerySpec {
  const words = searchWords(search ?? "");
  if (tagId && words.length > 0) {
    throw new Error("Use assunto ou busca, não os dois juntos.");
  }
  const longest = words.reduce((a, b) => (b.length > a.length ? b : a), "");
  return {
    tagId: tagId || null,
    token: longest ? longest.slice(0, MAX_TOKEN_LENGTH) : null,
    words,
  };
}
