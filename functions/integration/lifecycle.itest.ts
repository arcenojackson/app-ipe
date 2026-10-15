import {beforeEach, describe, expect, it} from "vitest";
import {setElectionStatus} from "../src/elections/lifecycle";
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
