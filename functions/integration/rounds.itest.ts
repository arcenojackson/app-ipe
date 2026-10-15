import {beforeEach, describe, expect, it} from "vitest";
import {
  bumpVotedCount, castVote, closeRound, openRound,
} from "../src/elections/rounds";
import {
  ADMIN, ELECTION, MEMBER, MEMBER2, MEMBER3, OUTSIDER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const ana = {id: MEMBER, name: "Ana"};
const bia = {id: MEMBER2, name: "Bia"};
const caio = {id: MEMBER3, name: "Caio"};

const rounds = () => db.collection(`elections/${ELECTION}/rounds`);
const round = async (id: string) => (await rounds().doc(id).get()).data()!;

const seedRound = (id: string, over: Record<string, unknown> = {}) =>
  rounds().doc(id).set({
    position: "presidente",
    candidates: [ana, bia],
    type: "normal",
    status: "pending",
    votedCount: 0,
    ...over,
  });

const approve = (uid: string) =>
  db.doc(`elections/${ELECTION}/voters/${uid}`).set({
    name: uid, email: "", kind: "member", status: "approved",
  });

const vote = (uid: string, choice: string, roundId = "r1") =>
  castVote(db, uid, {electionId: ELECTION, roundId, choice});

beforeEach(async () => {
  await clearDb();
  await seedBase();
});

describe("openRound", () => {
  it("só admin abre; abre a rodada e zera o contador", async () => {
    await seedRound("r1");
    await expectCode(openRound(db, MEMBER, {electionId: ELECTION, roundId: "r1"}), "permission-denied");
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    const r = await round("r1");
    expect(r.status).toBe("open");
    expect(r.votedCount).toBe(0);
    expect(r.type).toBe("normal");
  });

  it("exige eleição aberta", async () => {
    await seedRound("r1");
    await db.doc(`elections/${ELECTION}`).update({status: "draft"});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("não abre duas votações ao mesmo tempo nem reabre uma já aberta", async () => {
    await seedRound("r1");
    await seedRound("r2", {position: "vice"});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r2"}), "failed-precondition");
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("tira dos candidatos quem já foi eleito em outro cargo", async () => {
    await seedRound("r0", {
      status: "closed",
      closedAt: new Date(1000),
      result: {winnerId: MEMBER},
    });
    await seedRound("r1", {position: "vice", candidates: [ana, bia, caio]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).candidates).toEqual([bia, caio]);
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs[0].get("removed")).toEqual([MEMBER]);
  });

  it("sobrando um candidato vira rodada 'single'", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {position: "vice", candidates: [ana, bia]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).type).toBe("single");
  });

  it("sem candidato elegível, recusa", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {position: "vice", candidates: [ana]});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("refazer o mesmo cargo mantém o vencedor anterior como elegível", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {candidates: [ana, bia]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).candidates).toEqual([ana, bia]);
  });
});

describe("castVote", () => {
  beforeEach(async () => {
    await seedRound("r1", {status: "open"});
    await approve(MEMBER);
  });

  it("registra voto, devolve recibo e mantém o sigilo", async () => {
    const res = await vote(MEMBER, MEMBER2);
    const ballot = await db.doc(`elections/${ELECTION}/rounds/r1/ballots/${res.receipt}`).get();
    expect(ballot.exists).toBe(true);
    expect(Object.keys(ballot.data()!)).toEqual(["choice"]);
    expect(ballot.get("choice")).toBe(MEMBER2);
    const voted = await db.doc(`elections/${ELECTION}/rounds/r1/voted/${MEMBER}`).get();
    expect(voted.exists).toBe(true);
    expect(voted.data()).toEqual({});
  });

  it("o voto não escreve no documento da rodada (sem disputa entre eleitores)", async () => {
    const before = (await rounds().doc("r1").get()).updateTime!.toMillis();
    await vote(MEMBER, MEMBER2);
    const after = (await rounds().doc("r1").get()).updateTime!.toMillis();
    expect(after).toBe(before);
  });

  it("segundo voto do mesmo eleitor é recusado", async () => {
    await vote(MEMBER, MEMBER2);
    await expectCode(vote(MEMBER, "blank"), "already-exists");
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    expect(ballots.size).toBe(1);
  });

  it("duas requisições simultâneas geram um único voto", async () => {
    const results = await Promise.allSettled([vote(MEMBER, MEMBER2), vote(MEMBER, MEMBER2)]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    expect(ballots.size).toBe(1);
    const voted = await db.collection(`elections/${ELECTION}/rounds/r1/voted`).get();
    expect(voted.size).toBe(1);
  });

  it("eleitor inexistente, pendente ou recusado não vota", async () => {
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
    await db.doc(`elections/${ELECTION}/voters/${OUTSIDER}`).set({status: "pending", kind: "guest", name: "x"});
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
    await db.doc(`elections/${ELECTION}/voters/${OUTSIDER}`).update({status: "rejected"});
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
  });

  it("escolha fora da lista é inválida (inclusive yes/no em rodada normal)", async () => {
    await expectCode(vote(MEMBER, "ninguem"), "invalid-argument");
    await expectCode(vote(MEMBER, "yes"), "invalid-argument");
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    expect(ballots.size).toBe(0);
  });

  it("rodada 'single' aceita yes/no/blank e recusa candidato", async () => {
    await seedRound("r2", {status: "open", position: "vice", type: "single", candidates: [ana]});
    await rounds().doc("r1").update({status: "closed"});
    await expectCode(vote(MEMBER, MEMBER, "r2"), "invalid-argument");
    await vote(MEMBER, "yes", "r2");
  });

  it("rodada fechada ou pendente não recebe voto", async () => {
    await rounds().doc("r1").update({status: "closed"});
    await expectCode(vote(MEMBER, "blank"), "failed-precondition");
    await seedRound("r3", {status: "pending", position: "vice"});
    await expectCode(vote(MEMBER, "blank", "r3"), "failed-precondition");
  });

  it("eleição encerrada rejeita o voto", async () => {
    await db.doc(`elections/${ELECTION}`).update({status: "closed"});
    await expectCode(vote(MEMBER, "blank"), "failed-precondition");
  });
});

describe("bumpVotedCount (gatilho de contador ao vivo)", () => {
  it("soma 1 ao contador da rodada", async () => {
    await seedRound("r1", {status: "open"});
    await bumpVotedCount(db, ELECTION, "r1");
    await bumpVotedCount(db, ELECTION, "r1");
    expect((await round("r1")).votedCount).toBe(2);
  });

  it("não mexe no contador de rodada já encerrada (gatilho atrasado)", async () => {
    await seedRound("r1", {status: "closed", votedCount: 3});
    await bumpVotedCount(db, ELECTION, "r1");
    expect((await round("r1")).votedCount).toBe(3);
  });

  it("ignora rodada que não existe mais", async () => {
    await expect(bumpVotedCount(db, ELECTION, "sumiu")).resolves.toBeUndefined();
  });
});

describe("closeRound", () => {
  beforeEach(async () => {
    await seedRound("r1", {status: "open"});
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) await approve(uid);
  });

  it("só admin encerra; apura e grava o resultado", async () => {
    await vote(MEMBER, MEMBER);
    await vote(MEMBER2, MEMBER);
    await vote(MEMBER3, "blank");
    await expectCode(closeRound(db, MEMBER, {electionId: ELECTION, roundId: "r1"}), "permission-denied");
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.winnerId).toBe(MEMBER);
    expect(result.counts).toEqual({[MEMBER]: 2, [MEMBER2]: 0, blank: 1});
    expect(result.divergence).toBe(false);
    const r = await round("r1");
    expect(r.status).toBe("closed");
    expect(r.result.winnerId).toBe(MEMBER);
    expect(r.closedAt).toBeDefined();
    // O contador exibido é corrigido para o valor exato no encerramento.
    expect(r.votedCount).toBe(3);
  });

  it("empate devolve os empatados", async () => {
    await vote(MEMBER, MEMBER);
    await vote(MEMBER2, MEMBER2);
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.winnerId).toBeNull();
    expect(result.tie.sort()).toEqual([MEMBER, MEMBER2].sort());
  });

  it("todos em branco ou ninguém votou: sem vencedor e sem empate", async () => {
    await vote(MEMBER, "blank");
    const blank = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(blank.winnerId).toBeNull();
    expect(blank.tie).toEqual([]);

    await seedRound("r2", {status: "open", position: "vice"});
    const empty = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r2"});
    expect(empty.total).toBe(0);
    expect(empty.winnerId).toBeNull();
    expect(empty.tie).toEqual([]);
  });

  it("detecta divergência entre voted e ballots", async () => {
    await vote(MEMBER, MEMBER);
    await db.doc(`elections/${ELECTION}/rounds/r1/voted/ghost`).set({});
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.divergence).toBe(true);
    expect(result.votedCount).toBe(2);
  });

  it("não encerra rodada que não está aberta", async () => {
    await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    await expectCode(closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("voto concorrente com o encerramento: nunca sobra voted sem ballot", async () => {
    const settled = await Promise.allSettled([
      vote(MEMBER, MEMBER),
      vote(MEMBER2, MEMBER),
      vote(MEMBER3, MEMBER),
      closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}),
    ]);
    expect(settled[3].status).toBe("fulfilled");
    const accepted = settled.slice(0, 3).filter((s) => s.status === "fulfilled").length;
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    const voted = await db.collection(`elections/${ELECTION}/rounds/r1/voted`).get();
    const r = await round("r1");
    expect(ballots.size).toBe(accepted);
    expect(voted.size).toBe(accepted);
    // Tudo que foi aceito antes do fechamento entra na contagem.
    expect(r.result.total).toBe(accepted);
    expect(r.result.divergence).toBe(false);
  });
});
