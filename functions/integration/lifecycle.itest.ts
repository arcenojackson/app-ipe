import {beforeEach, describe, expect, it} from "vitest";
import {
  applyBoard,
  createElection,
  setElectionStatus,
} from "../src/elections/lifecycle";
import {applyDueBoards} from "../src/elections/transitions";
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
const transition = async () =>
  (await db.doc(`boardTransitions/${ELECTION}`).get()).data();
const apply = (uid = DIRECTOR) => applyBoard(db, uid, {electionId: ELECTION});
const ORIGINAL_BOARD = {presidente: [DIRECTOR], vice: [DIRECTOR2]};
// 01/01/2027 ao meio-dia em São Paulo.
const JAN_1_NOON = new Date("2027-01-01T15:00:00Z");

describe("applyBoard (registra a diretoria em espera)", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("closed");
  });

  it("só diretor da eleição registra", async () => {
    await decided("presidente", MEMBER2);
    for (const uid of [MEMBER, OTHER_DIRECTOR, ADMIN]) {
      await expectCode(apply(uid), "permission-denied");
    }
    expect(await transition()).toBeUndefined();
  });

  it("não altera a diretoria atual: grava só os decididos como pendentes", async () => {
    await decided("presidente", MEMBER2);
    const res = await apply();
    expect(res.winners).toEqual({presidente: MEMBER2});
    expect(res.missingRequired).toEqual(["vice"]);
    expect(await board()).toEqual(ORIGINAL_BOARD);
    const t = (await transition())!;
    expect(t.status).toBe("pending");
    expect(t.societyId).toBe(SOCIETY);
    expect(t.winners).toEqual({presidente: MEMBER2});
    expect(t.effectiveAt.toMillis()).toBe(res.effectiveAtMs);
    expect((await db.doc(`elections/${ELECTION}`).get()).get("boardAppliedAt")).toBeDefined();
  });

  it("presidente e vice decididos: nada obrigatório falta", async () => {
    await decided("presidente", MEMBER);
    await decided("vice", MEMBER2);
    expect((await apply()).missingRequired).toEqual([]);
  });

  it("cargo não decidido não entra", async () => {
    await decided("presidente", MEMBER);
    await seedCargo("vice", {stage: "awaiting3", winnerId: MEMBER2});
    expect((await apply()).winners).toEqual({presidente: MEMBER});
  });

  it("nenhum cargo decidido: erro claro e nada é registrado", async () => {
    await expectCode(apply(), "failed-precondition");
    expect(await transition()).toBeUndefined();
  });

  it("diretoria antiga com pessoas (lista) é recusada, sem registrar nada", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: ["a", "b"]});
    await decided("vice", MEMBER2);
    await expectCode(apply(), "failed-precondition");
    expect(await transition()).toBeUndefined();
    expect(await board()).toEqual(["a", "b"]);
  });

  it("repetir substitui o registro pendente (uma só vez, com o mesmo createdAt)", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    const first = (await transition())!;
    await decided("presidente", MEMBER3);
    await apply();
    const second = (await transition())!;
    expect(second.winners).toEqual({presidente: MEMBER3});
    expect(second.createdAt.toMillis()).toBe(first.createdAt.toMillis());
    const all = await db.collection("boardTransitions").get();
    expect(all.size).toBe(1);
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.filter((d) => d.get("type") === "board_scheduled")).toHaveLength(2);
  });

  it("depois que a diretoria assumiu, não registra de novo", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    await applyDueBoards(db, JAN_1_NOON);
    await expectCode(apply(), "failed-precondition");
  });
});

describe("applyDueBoards (rotina de 01/01)", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("closed");
  });

  it("antes da vigência não muda nada", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    const res = await applyDueBoards(db, new Date("2026-12-31T20:00:00Z"));
    expect(res.applied).toEqual([]);
    expect(await board()).toEqual(ORIGINAL_BOARD);
    expect((await transition())!.status).toBe("pending");
  });

  it("na vigência troca só os cargos eleitos e marca como aplicada", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    const res = await applyDueBoards(db, JAN_1_NOON);
    expect(res.applied).toEqual([ELECTION]);
    expect(await board()).toEqual({presidente: [MEMBER2], vice: [DIRECTOR2]});
    const t = (await transition())!;
    expect(t.status).toBe("applied");
    expect(t.appliedAt).toBeDefined();
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.filter((d) => d.get("type") === "board_applied")).toHaveLength(1);
  });

  it("usa as chaves do app, inclusive a do 2º secretário, sem duplicar cargo", async () => {
    await db.doc(`societies/${SOCIETY}`).update({board: {Presidente: ["old"]}});
    await decided("presidente", MEMBER);
    await decided("secretario2", MEMBER2);
    await decided("tesoureiro", MEMBER3);
    await apply();
    await applyDueBoards(db, JAN_1_NOON);
    expect(await board()).toEqual({
      presidente: [MEMBER],
      "2º secretario(a)": [MEMBER2],
      "tesoureiro(a)": [MEMBER3],
    });
  });

  it("rodar de novo não reaplica", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    await applyDueBoards(db, JAN_1_NOON);
    await db.doc(`societies/${SOCIETY}`).update({board: {presidente: ["x"]}});
    const res = await applyDueBoards(db, JAN_1_NOON);
    expect(res.applied).toEqual([]);
    expect(await board()).toEqual({presidente: ["x"]});
  });

  it("sociedade com diretoria em formato antigo vira failed e não trava as outras", async () => {
    await decided("presidente", MEMBER2);
    await apply();
    await db.doc(`societies/${SOCIETY}`).update({board: ["a"]});
    await db.doc("boardTransitions/e2").set({
      electionId: "e2",
      societyId: OTHER_SOCIETY,
      winners: {presidente: MEMBER},
      effectiveAt: new Date("2027-01-01T03:00:00Z"),
      status: "pending",
      createdAt: new Date("2026-12-20T12:00:00Z"),
    });
    const res = await applyDueBoards(db, JAN_1_NOON);
    expect(res.applied).toEqual(["e2"]);
    expect(res.failed.map((f) => f.electionId)).toEqual([ELECTION]);
    expect((await transition())!.status).toBe("failed");
    expect((await db.doc(`societies/${OTHER_SOCIETY}`).get()).get("board"))
      .toEqual({presidente: [MEMBER]});
  });
});
