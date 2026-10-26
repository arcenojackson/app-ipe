export type TagKind = "type" | "subject" | "age";

// Documento de teaching_tags/{id}.
export interface Tag {
  id: string;
  kind: TagKind;
  name: string;
  order: number;
  active: boolean;
}

// Tags de um item: ids de teaching_tags, por tipo.
export interface ItemTags {
  typeTags: string[];
  subjectTags: string[];
  ageTags: string[];
}

export const EMPTY_TAGS: ItemTags = {typeTags: [], subjectTags: [], ageTags: []};

export const TAG_KINDS: TagKind[] = ["type", "subject", "age"];

export const TAG_FIELD: Record<TagKind, keyof ItemTags> = {
  type: "typeTags",
  subject: "subjectTags",
  age: "ageTags",
};

export const TAG_KIND_LABEL: Record<TagKind, string> = {
  type: "Tipo",
  subject: "Assunto",
  age: "Faixa",
};

const MISSING_MESSAGE: Record<TagKind, string> = {
  type: "Escolha pelo menos uma tag de tipo.",
  subject: "Escolha pelo menos uma tag de assunto.",
  age: "Escolha pelo menos uma tag de faixa.",
};

// Todo envio exige pelo menos uma tag de cada tipo.
export function validateTags(tags: ItemTags): string | null {
  for (const kind of TAG_KINDS) {
    if (tags[TAG_FIELD[kind]].length === 0) return MISSING_MESSAGE[kind];
  }
  return null;
}

export const REMOVED_TAG_NAME = "Tag removida";

// Mostrado quando a leitura de teaching_tags falha (menus ficariam vazios sem explicação).
export const TAGS_LOAD_HINT = "Recarregue a página.";

export function tagName(byId: Map<string, Tag>, id: string): string {
  return byId.get(id)?.name ?? REMOVED_TAG_NAME;
}
