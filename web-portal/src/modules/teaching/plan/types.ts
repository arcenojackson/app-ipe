// Uma linha do plano pedagógico (documento de teaching_plan/{id}).
export interface PlanRow {
  id: string;
  lesson: number;
  theme: string;
  leader: string;
  knowledge: string;
  skills: string;
  essentials: string;
  notes: string;
  references: string;
}

export type PlanField = Exclude<keyof PlanRow, "id">;

// Colunas na ordem da planilha original.
export const PLAN_COLUMNS: Array<{field: PlanField; label: string; long: boolean}> = [
  {field: "lesson", label: "Aula", long: false},
  {field: "theme", label: "Tema", long: false},
  {field: "leader", label: "Orientador responsável", long: false},
  {field: "knowledge", label: "Objetos de conhecimento", long: true},
  {field: "skills", label: "Habilidades necessárias", long: true},
  {field: "essentials", label: "Aprendizagens essenciais", long: true},
  {field: "notes", label: "Observações", long: true},
  {field: "references", label: "Referências bibliográficas", long: true},
];
