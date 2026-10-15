export interface RoundSummary {
  position: string;
  status: string;
  closedAtMs: number;
  winnerId: string | null;
}

// Vencedor de cada cargo: vale a rodada fechada mais recente do cargo.
// Se a mais recente não tem vencedor, o cargo fica sem vencedor.
export const pickWinners = (
  rounds: RoundSummary[]
): Record<string, string> => {
  const latest: Record<string, RoundSummary> = {};
  for (const round of rounds) {
    if (round.status !== "closed") continue;
    const current = latest[round.position];
    if (!current || round.closedAtMs >= current.closedAtMs) {
      latest[round.position] = round;
    }
  }
  const winners: Record<string, string> = {};
  for (const [position, round] of Object.entries(latest)) {
    if (round.winnerId) winners[position] = round.winnerId;
  }
  return winners;
};

// Quem já foi eleito para algum cargo diferente de `position`.
export const electedElsewhere = (
  rounds: RoundSummary[],
  position: string
): Set<string> =>
  new Set(
    Object.values(pickWinners(rounds.filter((r) => r.position !== position)))
  );
