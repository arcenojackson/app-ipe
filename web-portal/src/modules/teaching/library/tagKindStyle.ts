import type {TagKind} from "./tags";

// Cor fixa de cada tipo de tag. Tipo usa o `secondary` do app; Assunto e Faixa
// são derivados dele (mesma saturação/luminosidade, outro matiz).
export const TAG_KIND_STYLE: Record<TagKind, {chip: string; solid: string; dot: string}> = {
  type: {
    chip: "border-secondary bg-secondary/20",
    solid: "border-secondary bg-secondary/40",
    dot: "bg-secondary",
  },
  subject: {
    chip: "border-[hsl(38_60%_50%)] bg-[hsl(38_60%_50%/0.18)]",
    solid: "border-[hsl(38_60%_50%)] bg-[hsl(38_60%_50%/0.4)]",
    dot: "bg-[hsl(38_60%_50%)]",
  },
  age: {
    chip: "border-[hsl(205_60%_55%)] bg-[hsl(205_60%_55%/0.18)]",
    solid: "border-[hsl(205_60%_55%)] bg-[hsl(205_60%_55%/0.4)]",
    dot: "bg-[hsl(205_60%_55%)]",
  },
};
