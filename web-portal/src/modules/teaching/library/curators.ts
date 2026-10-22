// Envio de curador e exclusão exigem 2 outros curadores: com menos de 3,
// nada disso consegue ser aprovado.
export const MIN_CURATORS = 3;

export function needsCurators(count: number): boolean {
  return count < MIN_CURATORS;
}
