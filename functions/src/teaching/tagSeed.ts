export type TagKind = "type" | "subject" | "age";

export interface SeedTag {
  id: string;
  kind: TagKind;
  name: string;
  order: number;
  active: true;
}

const PREFIX: Record<TagKind, string> = {
  type: "tipo",
  subject: "assunto",
  age: "faixa",
};

// Id estável: minúsculas, sem acento, hífens.
const slug = (name: string): string =>
  name
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

// Monta as tags de um tipo, numeradas a partir de 1.
const seed = (kind: TagKind, names: string[]): SeedTag[] =>
  names.map((name, index) => ({
    id: `${PREFIX[kind]}-${slug(name)}`,
    kind,
    name,
    order: index + 1,
    active: true,
  }));

// Ponto de partida das tags (spec 4.2). Depois disso, criar e editar tags é
// manual, direto no banco; o script só cria as que ainda não existem.
export const TAG_SEED: SeedTag[] = [
  ...seed("type", [
    "Sermões",
    "Recursos pedagógicos",
    "Fichamentos e resumos",
    "Bibliografia",
    "Aulas",
    "Artigos",
  ]),
  ...seed("subject", [
    "Identidade cristã e evangelho",
    "Bíblia: autoridade e inspiração",
    "Interpretação bíblica",
    "História da redenção",
    "Cosmovisão e síntese da fé reformada",
    "Reforma e os cinco Solas",
    "Existência e revelação de Deus",
    "Atributos de Deus e adoração",
    "Trindade",
    "Soberania e providência",
    "O problema do mal e o sofrimento",
    "Criação e imagem de Deus",
    "Queda, pecado e idolatria",
    "Pessoa de Cristo",
    "Obra de Cristo",
    "Salvação, eleição e graça",
    "Justificação, adoção e santificação",
    "Espírito Santo e seus dons",
    "Crescimento cristão e meios de graça",
    "Igreja e missão",
    "Sacramentos",
    "Ética, lei de Deus e consciência",
    "Relacionamentos, sexualidade e redes sociais",
    "Vocação, trabalho e dinheiro",
    "Escatologia e vida futura",
  ]),
  ...seed("age", ["UCP", "UPA", "UMP", "ADULTOS", "CASAIS", "SAF", "HOMENS"]),
];
