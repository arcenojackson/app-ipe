import {beforeEach, describe, expect, it} from "vitest";
import {
  applyBoard,
  createElection,
  setElectionStatus,
} from "../src/elections/lifecycle";
import {
  ADMIN, DIRECTOR, DIRECTOR2, ELECTION, MEMBER, MEMBER2, MEMBER3, OTHER_DIRECTOR,
  OTHER_SOCIETY,
  SOCIETY, clearDb, db, expectCode, seedBase,
} from "./helpers";

const status = async () =>
  (await db.doc(`elections/${ELECTION}`).get()).get("status");

const input = (over: Record<string, unknown> = {}) => ({
  societyId: SOCIETY,
  title: "Eleição UMP 2026",
  scheduledAtMs: Date.UTC(2026, 9, 31, 22, 0),
  positions: ["presidente", "vice", "tesoureiro"],
  ...over,
});

describe("createElection", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase();
  });

  it("diretor da sociedade cria: rascunho, snapshot dos diretores e cargos parados", async () => {
    const {electionId} = await createElection(db, DIRECTOR, input());
    const election = (await db.doc(`elections/${electionId}`).get()).data()!;
    expect(election.status).toBe("draft");
    expect(election.societyId).toBe(SOCIETY);
    expect(election.societyName).toBe("UMP");
    expect(election.title).toBe("Eleição UMP 2026");
    expect([...election.directorIds].sort()).toEqual([DIRECTOR, DIRECTOR2]);
    expect(election.positions).toEqual(["presidente", "vice", "tesoureiro"]);
    expect(election.createdBy).toBe(DIRECTOR);
    expect(election.scheduledAt.toMillis()).toBe(Date.UTC(2026, 9, 31, 22, 0));

    const cargos = await db.collection(`elections/${electionId}/cargos`).get();
    expect(cargos.docs.map((d) => d.id).sort())
      .toEqual(["presidente", "tesoureiro", "vice"]);
    for (const c of cargos.docs) {
      expect(c.data()).toEqual({
        stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null,
      });
    }
    const events = await db.collection(`elections/${electionId}/events`).get();
    expect(events.docs.map((d) => d.get("type"))).toEqual(["election_created"]);
  });

  it("diretor de outra sociedade, admin global e membro comum são recusados", async () => {
    for (const uid of [OTHER_DIRECTOR, ADMIN, MEMBER]) {
      await expectCode(createElection(db, uid, input()), "permission-denied");
    }
    const all = await db.collection("elections").get();
    expect(all.size).toBe(1); // só a eleição semeada
  });

  it("sociedade sem diretoria não tem eleição", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: {}});
    await expectCode(createElection(db, ADMIN, input()), "failed-precondition");
    await db.doc(`societies/${SOCIETY}`).update({board: []});
    await expectCode(createElection(db, DIRECTOR, input()), "failed-precondition");
  });

  it("sociedade inexistente", async () => {
    await expectCode(createElection(db, DIRECTOR, input({societyId: "nope"})), "not-found");
  });

  it("valida cargos, título e data", async () => {
    await expectCode(createElection(db, DIRECTOR, input({positions: ["presidente"]})), "invalid-argument");
    await expectCode(createElection(db, DIRECTOR, input({positions: ["presidente", "vice", "pastor"]})), "invalid-argument");
    await expectCode(createElection(db, DIRECTOR, input({title: "  "})), "invalid-argument");
    await expectCode(createElection(db, DIRECTOR, input({scheduledAtMs: "amanhã"})), "invalid-argument");
  });

  it("aceita diretoria no formato antigo (lista de ids)", async () => {
    await db.doc(`societies/${OTHER_SOCIETY}`).update({board: [OTHER_DIRECTOR]});
    const {electionId} = await createElection(
      db, OTHER_DIRECTOR, input({societyId: OTHER_SOCIETY})
    );
    const election = (await db.doc(`elections/${electionId}`).get()).data()!;
    expect(election.directorIds).toEqual([OTHER_DIRECTOR]);
  });
});

describe("setElectionStatus", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("draft");
  });

  it("só diretor da eleição muda o status", async () => {
    for (const uid of [MEMBER, OTHER_DIRECTOR, ADMIN]) {
      await expectCode(
        setElectionStatus(db, uid, {electionId: ELECTION, status: "open"}),
        "permission-denied"
      );
    }
    expect(await status()).toBe("draft");
  });

  it("draft → open → closed", async () => {
    await setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "open"});
    expect(await status()).toBe("open");
    await setElectionStatus(db, DIRECTOR2, {electionId: ELECTION, status: "closed"});
    expect(await status()).toBe("closed");
  });

  it("não fecha eleição em rascunho nem reabre fechada", async () => {
    await expectCode(
      setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
    await setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "open"});
    await setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "closed"});
    await expectCode(
      setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "open"}),
      "failed-precondition"
    );
  });

  it("não encerra a eleição com votação aberta", async () => {
    await setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "open"});
    await db.doc(`elections/${ELECTION}/rounds/r1`).set({
      position: "presidente", status: "open", candidates: [], type: "normal",
    });
    await expectCode(
      setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
  });

  it("status inválido", async () => {
    await expectCode(
      setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "draft"}),
      "invalid-argument"
    );
  });

  it("registra evento", async () => {
    await setElectionStatus(db, DIRECTOR, {electionId: ELECTION, status: "open"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.map((d) => d.get("type"))).toEqual(["election_opened"]);
  });
});

const seedCargo = (position: string, over: Record<string, unknown> = {}) =>
  db.doc(`elections/${ELECTION}/cargos/${position}`).set({
    stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null, ...over,
  });
const decided = (position: string, winnerId: string) =>
  seedCargo(position, {stage: "decided", winnerId});

const board = async () => (await db.doc(`societies/${SOCIETY}`).get()).get("board");
const directorIds = async () =>
  (await db.doc(`elections/${ELECTION}`).get()).get("directorIds") as string[];
const apply = (uid = DIRECTOR) => applyBoard(db, uid, {electionId: ELECTION});

describe("applyBoard", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("closed");
  });

  it("só diretor da eleição aplica", async () => {
    await decided("presidente", MEMBER2);
    for (const uid of [MEMBER, OTHER_DIRECTOR, ADMIN]) {
      await expectCode(apply(uid), "permission-denied");
    }
    expect(await board()).toEqual({presidente: [DIRECTOR], vice: [DIRECTOR2]});
  });

  it("grava só os cargos decididos, preserva os demais e avisa o que falta de obrigatório", async () => {
    await decided("presidente", MEMBER2);
    const res = await apply();
    expect(res.winners).toEqual({presidente: MEMBER2});
    expect(res.missingRequired).toEqual(["vice"]);
    expect(await board()).toEqual({presidente: [MEMBER2], vice: [DIRECTOR2]});
    expect((await db.doc(`elections/${ELECTION}`).get()).get("boardAppliedAt")).toBeDefined();
  });

  it("presidente e vice decididos: nada obrigatório falta", async () => {
    await decided("presidente", MEMBER);
    await decided("vice", MEMBER2);
    expect((await apply()).missingRequired).toEqual([]);
  });

  it("usa as chaves do app, inclusive a do 2º secretário", async () => {
    await decided("secretario", MEMBER);
    await decided("secretario2", MEMBER2);
    await decided("tesoureiro", MEMBER3);
    await apply();
    const b = await board();
    expect(b["secretario(a)"]).toEqual([MEMBER]);
    expect(b["2º secretario(a)"]).toEqual([MEMBER2]);
    expect(b["tesoureiro(a)"]).toEqual([MEMBER3]);
  });

  it("cargo não decidido não entra", async () => {
    await decided("presidente", MEMBER);
    await seedCargo("vice", {stage: "awaiting3", winnerId: MEMBER2});
    const res = await apply();
    expect(res.winners).toEqual({presidente: MEMBER});
  });

  it("nenhum cargo decidido: erro claro e nada muda", async () => {
    await expectCode(apply(), "failed-precondition");
    expect(await board()).toEqual({presidente: [DIRECTOR], vice: [DIRECTOR2]});
  });

  it("diretoria vazia em formato de lista (sociedade nova) vira mapa", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: []});
    await decided("vice", MEMBER2);
    await apply();
    expect(await board()).toEqual({vice: [MEMBER2]});
  });

  it("diretoria antiga com pessoas (lista) é recusada, sem perder ninguém", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: ["a", "b"]});
    await decided("vice", MEMBER2);
    await expectCode(apply(), "failed-precondition");
    expect(await board()).toEqual(["a", "b"]);
  });

  it("não duplica cargo gravado como 'Presidente'", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: {Presidente: ["old"]}});
    await decided("presidente", MEMBER2);
    await apply();
    expect(await board()).toEqual({presidente: [MEMBER2]});
  });

  it("os novos diretores passam a ter acesso e os antigos continuam", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    expect((await directorIds()).sort()).toEqual([DIRECTOR, DIRECTOR2, MEMBER2].sort());
    // Quem acabou de ser eleito já consegue conduzir/ver a eleição.
    await apply(MEMBER2);
  });

  it("registra evento e pode ser reaplicada", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    await apply();
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.filter((d) => d.get("type") === "board_applied")).toHaveLength(2);
  });
});
