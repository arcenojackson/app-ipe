import {beforeEach, describe, expect, it} from "vitest";
import {
  bumpVotedCount,
  castVote,
  closeScrutiny,
  startScrutiny,
} from "../src/elections/scrutinies";
import {
  ADMIN, DIRECTOR, ELECTION, MEMBER, MEMBER2, MEMBER3, OTHER_DIRECTOR, OUTSIDER,
  clearDb, db, expectCode, seedBase,
} from "./helpers";

const ana = {id: MEMBER, name: "Ana"};
const bia = {id: MEMBER2, name: "Bia"};
const caio = {id: MEMBER3, name: "Caio"};

const electionRef = () => db.doc(`elections/${ELECTION}`);
const cargoRef = (position: string) => electionRef().collection("cargos").doc(position);
const roundsRef = () => electionRef().collection("rounds");

const seedCargo = (position: string, over: Record<string, unknown> = {}) =>
  cargoRef(position).set({
    stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null, ...over,
  });

const seedRound = (id: string, over: Record<string, unknown> = {}) =>
  roundsRef().doc(id).set({
    position: "presidente", cycle: 1, number: 1, status: "open",
    options: [ana, bia, caio], votedCount: 0, ...over,
  });

const approve = (uid: string, status = "approved") =>
  electionRef().collection("voters").doc(uid).set({
    name: uid, email: "", kind: "member", status,
  });

const cargo = async (position: string) => (await cargoRef(position).get()).data()!;
const round = async (id: string) => (await roundsRef().doc(id).get()).data()!;

const start = (position = "presidente", uid = DIRECTOR) =>
  startScrutiny(db, uid, {electionId: ELECTION, position});
const close = (position = "presidente", uid = DIRECTOR) =>
  closeScrutiny(db, uid, {electionId: ELECTION, position});
const vote = (uid: string, choice: string, roundId: string) =>
  castVote(db, uid, {electionId: ELECTION, roundId, choice});

// n eleitores liberados p1..pn (presentes de verdade, fora da lista de membros).
const presentes = async (n: number): Promise<string[]> => {
  const uids = Array.from({length: n}, (_, i) => `p${i + 1}`);
  for (const uid of uids) await approve(uid);
  return uids;
};

beforeEach(async () => {
  await clearDb();
  await seedBase();
  for (const position of ["presidente", "vice", "secretario", "secretario2", "tesoureiro"]) {
    await seedCargo(position);
  }
});

describe("startScrutiny", () => {
  it("diretor inicia o 1º escrutínio com todos os membros como opção", async () => {
    const res = await start();
    expect(res.number).toBe(1);
    const r = await round(res.roundId);
    expect(r).toMatchObject({position: "presidente", cycle: 1, number: 1, status: "open", votedCount: 0});
    expect(r.options).toEqual([ana, bia, caio]);
    expect((await cargo("presidente")).stage).toBe("scrutiny1");
    const events = await electionRef().collection("events").get();
    expect(events.docs.map((d) => d.get("type"))).toContain("scrutiny_started");
  });

  it("quem já foi eleito em outro cargo não é opção do 1º escrutínio", async () => {
    await seedCargo("vice", {stage: "decided", winnerId: MEMBER});
    const res = await start("presidente");
    expect((await round(res.roundId)).options).toEqual([bia, caio]);
  });

  it("quem foi removido de outro cargo volta como opção", async () => {
    // O cargo `vice` terminou o ciclo sem eleito (reiniciado): ninguém fica de fora.
    await seedCargo("vice", {stage: "idle", cycle: 2});
    const res = await start("presidente");
    expect((await round(res.roundId)).options).toHaveLength(3);
  });

  it("só um escrutínio aberto por vez na eleição inteira", async () => {
    await start("presidente");
    await expectCode(start("vice"), "failed-precondition");
  });

  it("eleição fora de 'open' não inicia", async () => {
    await electionRef().update({status: "draft"});
    await expectCode(start(), "failed-precondition");
  });

  it("só diretor da eleição: diretor de outra sociedade, admin global e membro são recusados", async () => {
    for (const uid of [OTHER_DIRECTOR, ADMIN, MEMBER]) {
      await expectCode(start("presidente", uid), "permission-denied");
    }
    expect((await cargo("presidente")).stage).toBe("idle");
  });

  it("cargo que não está na eleição", async () => {
    await expectCode(start("pastor"), "invalid-argument");
  });

  it("2º escrutínio usa os candidatos confirmados; sem candidatos, recusa", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates: []});
    await expectCode(start(), "failed-precondition");
    await seedCargo("presidente", {
      stage: "confirming",
      candidates: [{id: MEMBER2, name: "Bia", votes: 3}, {id: MEMBER, name: "Ana", votes: 1}],
    });
    const res = await start();
    expect(res.number).toBe(2);
    expect((await round(res.roundId)).options).toEqual([
      {id: MEMBER2, name: "Bia"}, {id: MEMBER, name: "Ana"},
    ]);
    expect((await cargo("presidente")).stage).toBe("scrutiny2");
  });

  it("3º escrutínio parte de awaiting3 com os mesmos candidatos", async () => {
    await seedCargo("presidente", {
      stage: "awaiting3", candidates: [{id: MEMBER, name: "Ana", votes: 2}],
    });
    const res = await start();
    expect(res.number).toBe(3);
    expect((await round(res.roundId)).options).toEqual([{id: MEMBER, name: "Ana"}]);
  });

  it("estados que não permitem iniciar", async () => {
    for (const stage of ["scrutiny1", "scrutiny2", "scrutiny3", "tiebreak", "decided"]) {
      await seedCargo("presidente", {stage});
      await expectCode(start(), "failed-precondition");
    }
  });
});

describe("castVote", () => {
  let roundId: string;
  beforeEach(async () => {
    await approve(MEMBER);
    roundId = (await start()).roundId;
  });

  it("registra o voto, devolve recibo e mantém o sigilo", async () => {
    const res = await vote(MEMBER, MEMBER2, roundId);
    const ballot = await roundsRef().doc(roundId).collection("ballots").doc(res.receipt).get();
    expect(Object.keys(ballot.data()!)).toEqual(["choice"]);
    expect(ballot.get("choice")).toBe(MEMBER2);
    const voted = await roundsRef().doc(roundId).collection("voted").doc(MEMBER).get();
    expect(voted.exists).toBe(true);
    expect(voted.data()).toEqual({});
  });

  it("o voto não escreve no documento da rodada", async () => {
    const before = (await roundsRef().doc(roundId).get()).updateTime!.toMillis();
    await vote(MEMBER, MEMBER2, roundId);
    expect((await roundsRef().doc(roundId).get()).updateTime!.toMillis()).toBe(before);
  });

  it("voto repetido é recusado e duas chamadas simultâneas geram um só ballot", async () => {
    await vote(MEMBER, MEMBER2, roundId);
    await expectCode(vote(MEMBER, "blank", roundId), "already-exists");
    await approve(MEMBER2);
    const results = await Promise.allSettled([
      vote(MEMBER2, MEMBER, roundId), vote(MEMBER2, MEMBER, roundId),
    ]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const ballots = await roundsRef().doc(roundId).collection("ballots").get();
    expect(ballots.size).toBe(2);
  });

  it("aceita branco; recusa opção fora da lista", async () => {
    await vote(MEMBER, "blank", roundId);
    await approve(MEMBER2);
    await expectCode(vote(MEMBER2, "ninguem", roundId), "invalid-argument");
    await expectCode(vote(MEMBER2, OUTSIDER, roundId), "invalid-argument");
  });

  it("eleitor inexistente, pendente ou recusado não vota", async () => {
    await expectCode(vote(OUTSIDER, "blank", roundId), "permission-denied");
    await approve(OUTSIDER, "pending");
    await expectCode(vote(OUTSIDER, "blank", roundId), "permission-denied");
    await approve(OUTSIDER, "rejected");
    await expectCode(vote(OUTSIDER, "blank", roundId), "permission-denied");
  });

  it("escrutínio fechado ou eleição encerrada rejeitam o voto", async () => {
    await roundsRef().doc(roundId).update({status: "closed"});
    await expectCode(vote(MEMBER, "blank", roundId), "failed-precondition");
    await roundsRef().doc(roundId).update({status: "open"});
    await electionRef().update({status: "closed"});
    await expectCode(vote(MEMBER, "blank", roundId), "failed-precondition");
  });

  it("eleitor liberado depois do início e antes do encerramento vota e entra no total de presentes", async () => {
    await approve("late");
    await vote("late", MEMBER, roundId);
    const out = await close();
    expect(out.result.presentCount).toBe(2);
    expect(out.result.total).toBe(1);
  });
});

describe("bumpVotedCount (gatilho do contador ao vivo)", () => {
  it("soma 1 numa rodada aberta, ignora fechada e inexistente", async () => {
    await seedRound("r1");
    await bumpVotedCount(db, ELECTION, "r1");
    await bumpVotedCount(db, ELECTION, "r1");
    expect((await round("r1")).votedCount).toBe(2);
    await roundsRef().doc("r1").update({status: "closed"});
    await bumpVotedCount(db, ELECTION, "r1");
    expect((await round("r1")).votedCount).toBe(2);
    await expect(bumpVotedCount(db, ELECTION, "sumiu")).resolves.toBeUndefined();
  });
});

describe("closeScrutiny", () => {
  it("só diretor encerra", async () => {
    await start();
    for (const uid of [MEMBER, OTHER_DIRECTOR, ADMIN]) {
      await expectCode(close("presidente", uid), "permission-denied");
    }
  });

  it("sem escrutínio aberto no cargo", async () => {
    await expectCode(close(), "failed-precondition");
  });

  it("1º escrutínio: vira confirming com os votados por votos e grava o resultado", async () => {
    const {roundId} = await start();
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) await approve(uid);
    await vote(MEMBER, MEMBER2, roundId);
    await vote(MEMBER2, MEMBER2, roundId);
    await vote(MEMBER3, "blank", roundId);
    const out = await close();
    expect(out.stage).toBe("confirming");
    expect(out.result).toMatchObject({
      counts: {[MEMBER]: 0, [MEMBER2]: 2, [MEMBER3]: 0},
      blank: 1, total: 3, presentCount: 3, threshold: 2, winnerId: null, tie: [], divergence: false,
    });
    expect((await cargo("presidente")).candidates).toEqual([{id: MEMBER2, name: "Bia", votes: 2}]);
    const r = await round(roundId);
    expect(r.status).toBe("closed");
    expect(r.votedCount).toBe(3);
    expect(r.closedAt).toBeDefined();
  });

  it("1º escrutínio sem votos ou só brancos: confirming com lista vazia", async () => {
    const {roundId} = await start();
    await approve(MEMBER);
    await vote(MEMBER, "blank", roundId);
    const out = await close();
    expect(out.stage).toBe("confirming");
    expect((await cargo("presidente")).candidates).toEqual([]);
  });

  it("2º escrutínio: 6 de 10 presentes elege; 5 vai ao 3º", async () => {
    const uids = await presentes(10);
    await seedCargo("presidente", {
      stage: "confirming", candidates: [{id: MEMBER, name: "Ana", votes: 1}, {id: MEMBER2, name: "Bia", votes: 1}],
    });
    let roundId = (await start()).roundId;
    for (const uid of uids.slice(0, 6)) await vote(uid, MEMBER, roundId);
    let out = await close();
    expect(out.stage).toBe("decided");
    expect(out.result).toMatchObject({presentCount: 10, threshold: 6, winnerId: MEMBER});
    expect(await cargo("presidente")).toMatchObject({stage: "decided", winnerId: MEMBER});

    await seedCargo("vice", {
      stage: "confirming", candidates: [{id: MEMBER2, name: "Bia", votes: 1}, {id: MEMBER3, name: "Caio", votes: 1}],
    });
    roundId = (await start("vice")).roundId;
    for (const uid of uids.slice(0, 5)) await vote(uid, MEMBER2, roundId);
    out = await close("vice");
    expect(out.stage).toBe("awaiting3");
    expect((await cargo("vice")).stage).toBe("awaiting3");
  });

  it("3º escrutínio: empate vai ao diretor, único mais votado vence, só brancos reinicia", async () => {
    const uids = await presentes(4);
    const candidates = [{id: MEMBER, name: "Ana", votes: 1}, {id: MEMBER2, name: "Bia", votes: 1}];

    await seedCargo("presidente", {stage: "awaiting3", candidates});
    let roundId = (await start()).roundId;
    await vote(uids[0], MEMBER, roundId);
    await vote(uids[1], MEMBER2, roundId);
    let out = await close();
    expect(out.stage).toBe("tiebreak");
    expect(out.result.tie.sort()).toEqual([MEMBER, MEMBER2].sort());
    expect(await cargo("presidente")).toMatchObject({stage: "tiebreak"});
    expect((await cargo("presidente")).tiedIds.sort()).toEqual([MEMBER, MEMBER2].sort());

    await seedCargo("vice", {stage: "awaiting3", candidates});
    roundId = (await start("vice")).roundId;
    await vote(uids[0], MEMBER2, roundId);
    out = await close("vice");
    expect(out.stage).toBe("decided");
    expect(await cargo("vice")).toMatchObject({stage: "decided", winnerId: MEMBER2});

    await seedCargo("tesoureiro", {stage: "awaiting3", candidates});
    roundId = (await start("tesoureiro")).roundId;
    await vote(uids[0], "blank", roundId);
    await vote(uids[1], "blank", roundId);
    out = await close("tesoureiro");
    expect(out.stage).toBe("idle");
    expect(await cargo("tesoureiro")).toMatchObject({stage: "idle", cycle: 2, candidates: [], winnerId: null});
    // O novo ciclo parte do zero: o 1º escrutínio volta a listar os membros.
    const again = await start("tesoureiro");
    expect(again.number).toBe(1);
    expect((await round(again.roundId)).cycle).toBe(2);
  });

  it("presentes contam só os aprovados no encerramento", async () => {
    const {roundId} = await start();
    await approve(MEMBER);
    await approve(MEMBER2, "pending");
    await approve(MEMBER3, "rejected");
    await vote(MEMBER, MEMBER, roundId);
    const out = await close();
    expect(out.result.presentCount).toBe(1);
    expect(out.result.threshold).toBe(1);
  });

  it("marca divergência entre voted e ballots", async () => {
    const {roundId} = await start();
    await approve(MEMBER);
    await vote(MEMBER, MEMBER, roundId);
    await roundsRef().doc(roundId).collection("voted").doc("ghost").set({});
    const out = await close();
    expect(out.result.divergence).toBe(true);
    expect(out.result.total).toBe(1);
  });

  it("o log do encerramento não identifica votos", async () => {
    const {roundId} = await start();
    await approve(MEMBER);
    await vote(MEMBER, MEMBER2, roundId);
    await close();
    const events = await electionRef().collection("events").get();
    const closed = events.docs.find((d) => d.get("type") === "scrutiny_closed")!;
    expect(JSON.stringify(closed.data())).not.toContain(MEMBER);
    expect(closed.get("position")).toBe("presidente");
  });

  it("voto concorrente com o encerramento: nunca sobra voted sem ballot", async () => {
    const {roundId} = await start();
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) await approve(uid);
    const settled = await Promise.allSettled([
      vote(MEMBER, MEMBER, roundId),
      vote(MEMBER2, MEMBER, roundId),
      vote(MEMBER3, MEMBER, roundId),
      close(),
    ]);
    expect(settled[3].status).toBe("fulfilled");
    const accepted = settled.slice(0, 3).filter((s) => s.status === "fulfilled").length;
    const ballots = await roundsRef().doc(roundId).collection("ballots").get();
    const voted = await roundsRef().doc(roundId).collection("voted").get();
    const r = await round(roundId);
    expect(ballots.size).toBe(accepted);
    expect(voted.size).toBe(accepted);
    expect(r.result.total).toBe(accepted);
    expect(r.result.divergence).toBe(false);
  });
});
