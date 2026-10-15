import {beforeEach, describe, expect, it} from "vitest";
import {applyBoard, setElectionStatus} from "../src/elections/lifecycle";
import {
  ADMIN, ELECTION, MEMBER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const status = async () =>
  (await db.doc(`elections/${ELECTION}`).get()).get("status");

describe("setElectionStatus", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("draft");
  });

  it("só admin muda o status", async () => {
    await expectCode(
      setElectionStatus(db, MEMBER, {electionId: ELECTION, status: "open"}),
      "permission-denied"
    );
  });

  it("draft → open → closed", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    expect(await status()).toBe("open");
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"});
    expect(await status()).toBe("closed");
  });

  it("não fecha eleição em rascunho nem reabre fechada", async () => {
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"});
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"}),
      "failed-precondition"
    );
  });

  it("não encerra a eleição com votação aberta", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    await db.doc(`elections/${ELECTION}/rounds/r1`).set({
      position: "presidente", status: "open", candidates: [], type: "normal",
    });
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
  });

  it("status inválido", async () => {
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "draft"}),
      "invalid-argument"
    );
  });

  it("registra evento", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.map((d) => d.get("type"))).toEqual(["election_opened"]);
  });
});

const closedRound = (id: string, position: string, winnerId: string | null, ms: number) =>
  db.doc(`elections/${ELECTION}/rounds/${id}`).set({
    position, status: "closed", candidates: [], type: "normal",
    closedAt: new Date(ms), result: {winnerId},
  });

const board = async () => (await db.doc("societies/s1").get()).get("board");

describe("applyBoard", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("closed");
  });

  it("só admin aplica", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    await expectCode(applyBoard(db, MEMBER, {electionId: ELECTION}), "permission-denied");
  });

  it("troca só os cargos eleitos e preserva os demais", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    const res = await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(res.winners).toEqual({presidente: "m2"});
    expect(await board()).toEqual({presidente: ["m2"], vice: ["v1"]});
    const election = await db.doc(`elections/${ELECTION}`).get();
    expect(election.get("boardAppliedAt")).toBeDefined();
  });

  it("usa a chave com sufixo para secretário e tesoureiro", async () => {
    await closedRound("r1", "secretario", "m3", 1);
    await closedRound("r2", "tesoureiro", "m1", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    const b = await board();
    expect(b["secretario(a)"]).toEqual(["m3"]);
    expect(b["tesoureiro(a)"]).toEqual(["m1"]);
  });

  it("cargo decidido em desempate vale a rodada mais recente", async () => {
    await closedRound("r1", "presidente", null, 1);
    await closedRound("r2", "presidente", "m3", 2);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect((await board()).presidente).toEqual(["m3"]);
  });

  it("board em formato antigo (lista) vira mapa só com os eleitos", async () => {
    await db.doc("societies/s1").update({board: ["a", "b"]});
    await closedRound("r1", "vice", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(await board()).toEqual({vice: ["m2"]});
  });

  it("não duplica cargo gravado como 'Presidente'", async () => {
    await db.doc("societies/s1").update({board: {Presidente: ["old"]}});
    await closedRound("r1", "presidente", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(await board()).toEqual({presidente: ["m2"]});
  });

  it("sem cargo decidido, erro claro e nada muda", async () => {
    await db.doc(`elections/${ELECTION}/rounds/r1`).set({
      position: "presidente", status: "open", candidates: [], type: "normal",
    });
    await expectCode(applyBoard(db, ADMIN, {electionId: ELECTION}), "failed-precondition");
    expect(await board()).toEqual({presidente: ["old"], vice: ["v1"]});
  });

  it("registra evento e pode ser reaplicado", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.filter((d) => d.get("type") === "board_applied")).toHaveLength(2);
  });
});
