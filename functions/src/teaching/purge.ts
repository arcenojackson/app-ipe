export interface PurgeCounts {
  items: number;
  votes: number;
  notifications: number;
  objects: number;
}

const plural = (n: number, one: string, many: string): string =>
  `${n} ${n === 1 ? one : many}`;

// Texto do relatório do script de limpeza da biblioteca antiga.
export const describePurge = (
  counts: PurgeCounts,
  executed: boolean
): string => {
  const list = [
    plural(counts.items, "item", "itens"),
    plural(counts.votes, "voto", "votos"),
    plural(counts.notifications, "notificação", "notificações"),
    plural(counts.objects, "arquivo", "arquivos"),
  ].join(", ");
  if (!executed) {
    return `DRY-RUN: seriam apagados ${list}. Nada foi apagado.`;
  }
  return `Apagado: ${list}. Ficaram teaching_log, teaching_tags e os usuários.`;
};
