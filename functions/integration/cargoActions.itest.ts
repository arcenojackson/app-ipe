import {beforeEach, describe, expect, it} from "vitest";
import {
  pickOldest,
  removeCandidate,
  restartCargo,
} from "../src/elections/cargoActions";
import {
  castVote,
  closeScrutiny,
  startScrutiny,
} from "../src/elections/scrutinies";
import {
  ADMIN, DIRECTOR, DIRECTOR2, ELECTION, MEMBER, MEMBER2, MEMBER3, OTHER_DIRECTOR,
  clearDb, db, expectCode, seedBase,
} from "./helpers";

const electionRef = () => db.doc(`elections/${ELECTION}`);
const cargoRef = (position: string) => electionRef().collection("cargos").doc(position);
const roundsRef = () => electionRef().collection("rounds");

const seedCargo = (position: string, over: Record<string, unknown> = {}) =>
  cargoRef(position).set({
    stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null, ...over,
  });
const cargo = async (position: string) => (await cargoRef(position).get()).data()!;
const approve = (uid: string) =>
  electionRef().collection("voters").doc(uid).set({
    name: uid, email: "", kind: "member", status: "approved",
  });

const remove = (candidateId: string, position = "presidente", uid = DIRECTOR) =>
  removeCandidate(db, uid, {electionId: ELECTION, position, candidateId});
const restart = (position = "presidente", uid = DIRECTOR) =>
  restartCargo(db, uid, {electionId: ELECTION, position});
const oldest = (candidateId: string, position = "presidente", uid = DIRECTOR) =>
  pickOldest(db, uid, {electionId: ELECTION, position, candidateId});

const candidates = [
  {id: MEMBER, name: "Ana", votes: 2},
  {id: MEMBER2, name: "Bia", votes: 1},
];

beforeEach(async () => {
  await clearDb();
  await seedBase();
  for (const position of ["presidente", "vice", "secretario", "secretario2", "tesoureiro"]) {
    await seedCargo(position);
  }
});

describe("removeCandidate", () => {
  it("remove o candidato em confirming e registra o evento", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates});
    await remove(MEMBER);
    expect((await cargo("presidente")).candidates).toEqual([candidates[1]]);
    const events = await electionRef().collection("events").get();
    const ev = events.docs.find((d) => d.get("type") === "candidate_removed")!;
    expect(ev.data()).toMatchObject({
      position: "presidente", candidateId: MEMBER, candidateName: "Ana", actorId: DIRECTOR,
    });
  });

  it("só na confirmação e só de quem é candidato", async () => {
    await expectCode(remove(MEMBER), "failed-precondition"); // idle
    await seedCargo("presidente", {stage: "scrutiny2", candidates});
    await expectCode(remove(MEMBER), "failed-precondition");
    await seedCargo("presidente", {stage: "confirming", candidates});
    await expectCode(remove(MEMBER3), "failed-precondition");
  });

  it("só diretor da eleição", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates});
    for (const uid of [OTHER_DIRECTOR, ADMIN, MEMBER]) {
      await expectCode(remove(MEMBER2, "presidente", uid), "permission-denied");
    }
    expect((await cargo("presidente")).candidates).toHaveLength(2);
  });

  it("quem foi removido continua votando e volta como opção no cargo seguinte", async () => {
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) await approve(uid);
    // 1º escrutínio de Presidente: Ana e Bia recebem votos.
    const r1 = (await startScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "presidente"})).roundId;
    await castVote(db, MEMBER, {electionId: ELECTION, roundId: r1, choice: MEMBER});
    await castVote(db, MEMBER2, {electionId: ELECTION, roundId: r1, choice: MEMBER2});
    await closeScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "presidente"});
    // Ana declina.
    await remove(MEMBER);
    // 2º escrutínio: só Bia como opção; Ana (removida) ainda vota.
    const second = await startScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "presidente"});
    const opts = (await roundsRef().doc(second.roundId).get()).get("options");
    expect(opts).toEqual([{id: MEMBER2, name: "Bia"}]);
    await castVote(db, MEMBER, {electionId: ELECTION, roundId: second.roundId, choice: MEMBER2});
    await castVote(db, MEMBER3, {electionId: ELECTION, roundId: second.roundId, choice: "blank"});
    const out = await closeScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "presidente"});
    expect(out.result.presentCount).toBe(3); // Ana continua contando como presente
    // No cargo seguinte Ana volta a ser opção do 1º escrutínio.
    const next = await startScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "vice"});
    const ids = (await roundsRef().doc(next.roundId).get()).get("options").map((o: {id: string}) => o.id);
    expect(ids).toContain(MEMBER);
  });
});

describe("restartCargo", () => {
  it("confirmação sem candidatos volta a idle com cycle + 1 e novo 1º escrutínio com opções frescas", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates: []});
    await restart();
    expect(await cargo("presidente")).toMatchObject({
      stage: "idle", cycle: 2, candidates: [], tiedIds: [], winnerId: null,
    });
    const again = await startScrutiny(db, DIRECTOR, {electionId: ELECTION, position: "presidente"});
    expect(again.number).toBe(1);
    const r = (await roundsRef().doc(again.roundId).get()).data()!;
    expect(r.cycle).toBe(2);
    expect(r.options).toHaveLength(3);
  });

  it("tudo declinado: depois de remover todos, o cargo reinicia", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates: [candidates[0]]});
    await remove(MEMBER);
    await restart();
    expect((await cargo("presidente")).stage).toBe("idle");
  });

  it("com candidatos ou em outras fases é recusado", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates});
    await expectCode(restart(), "failed-precondition");
    for (const stage of ["scrutiny1", "scrutiny2", "awaiting3", "scrutiny3", "tiebreak", "decided"]) {
      await seedCargo("presidente", {stage});
      await expectCode(restart(), "failed-precondition");
    }
  });

  it("só diretor da eleição", async () => {
    await seedCargo("presidente", {stage: "confirming", candidates: []});
    for (const uid of [OTHER_DIRECTOR, ADMIN, MEMBER]) {
      await expectCode(restart("presidente", uid), "permission-denied");
    }
  });
});

describe("pickOldest", () => {
  const tied = {stage: "tiebreak", candidates, tiedIds: [MEMBER, MEMBER2]};

  it("decide entre os empatados e registra quem escolheu", async () => {
    await seedCargo("presidente", tied);
    await oldest(MEMBER2, "presidente", DIRECTOR2);
    expect(await cargo("presidente")).toMatchObject({
      stage: "decided", winnerId: MEMBER2, tiedIds: [],
    });
    const events = await electionRef().collection("events").get();
    const ev = events.docs.find((d) => d.get("type") === "oldest_picked")!;
    expect(ev.data()).toMatchObject({
      position: "presidente", candidateId: MEMBER2, candidateName: "Bia", actorId: DIRECTOR2,
    });
  });

  it("só em tiebreak e só entre os empatados", async () => {
    await expectCode(oldest(MEMBER), "failed-precondition"); // idle
    await seedCargo("presidente", tied);
    await expectCode(oldest(MEMBER3), "invalid-argument");
    expect((await cargo("presidente")).stage).toBe("tiebreak");
  });

  it("só diretor da eleição", async () => {
    await seedCargo("presidente", tied);
    for (const uid of [OTHER_DIRECTOR, ADMIN, MEMBER]) {
      await expectCode(oldest(MEMBER, "presidente", uid), "permission-denied");
    }
  });
});
