import {beforeEach, describe, expect, it} from "vitest";
import {checkIn, reviewVoter} from "../src/elections/voters";
import {
  ADMIN, ELECTION, MEMBER, OUTSIDER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const member = {uid: MEMBER, isAnonymous: false, email: "ana@ipe.org"};
const outsider = {uid: OUTSIDER, isAnonymous: false, email: "fora@x.org"};
const guest = {uid: "anon1", isAnonymous: true};

const voterDoc = async (uid: string) =>
  (await db.doc(`elections/${ELECTION}/voters/${uid}`).get()).data();

beforeEach(async () => {
  await clearDb();
  await seedBase();
});

describe("checkIn", () => {
  it("membro logado da sociedade entra aprovado, com nome do cadastro", async () => {
    const res = await checkIn(db, member, {electionId: ELECTION});
    expect(res).toEqual({status: "approved", kind: "member"});
    expect((await voterDoc(MEMBER))?.name).toBe("Ana");
  });

  it("convidado anônimo entra pendente com nome e e-mail informados", async () => {
    const res = await checkIn(db, guest, {
      electionId: ELECTION, name: " Dona Maria ", email: "maria@x.org",
    });
    expect(res).toEqual({status: "pending", kind: "guest"});
    const doc = await voterDoc("anon1");
    expect(doc?.name).toBe("Dona Maria");
    expect(doc?.email).toBe("maria@x.org");
  });

  it("convidado sem nome é recusado", async () => {
    await expectCode(checkIn(db, guest, {electionId: ELECTION}), "invalid-argument");
  });

  it("logado que não é da sociedade vira convidado pendente", async () => {
    const res = await checkIn(db, outsider, {electionId: ELECTION});
    expect(res).toEqual({status: "pending", kind: "guest"});
    expect((await voterDoc(OUTSIDER))?.name).toBe("Fora");
  });

  it("eleição fora de 'open' recusa o check-in", async () => {
    await db.doc(`elections/${ELECTION}`).update({status: "draft"});
    await expectCode(checkIn(db, member, {electionId: ELECTION}), "failed-precondition");
    await db.doc(`elections/${ELECTION}`).update({status: "closed"});
    await expectCode(checkIn(db, member, {electionId: ELECTION}), "failed-precondition");
  });

  it("eleição inexistente", async () => {
    await expectCode(checkIn(db, member, {electionId: "nope"}), "not-found");
  });

  it("check-in repetido é idempotente e NÃO derruba a aprovação", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    const again = await checkIn(db, guest, {electionId: ELECTION, name: "Outro nome"});
    expect(again).toEqual({status: "approved", kind: "guest"});
    expect((await voterDoc("anon1"))?.name).toBe("Maria");
  });

  it("chamadas simultâneas criam um único eleitor", async () => {
    const results = await Promise.all([
      checkIn(db, guest, {electionId: ELECTION, name: "Maria"}),
      checkIn(db, guest, {electionId: ELECTION, name: "Maria"}),
    ]);
    expect(results[0]).toEqual(results[1]);
    const snap = await db.collection(`elections/${ELECTION}/voters`).get();
    expect(snap.size).toBe(1);
  });
});

describe("reviewVoter", () => {
  it("só admin aprova", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await expectCode(
      reviewVoter(db, MEMBER, {electionId: ELECTION, voterId: "anon1", decision: "approved"}),
      "permission-denied"
    );
  });

  it("admin aprova e recusa, registrando quem decidiu", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    expect((await voterDoc("anon1"))?.status).toBe("approved");
    expect((await voterDoc("anon1"))?.reviewedBy).toBe(ADMIN);
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "rejected"});
    expect((await voterDoc("anon1"))?.status).toBe("rejected");
  });

  it("decisão inválida e eleitor inexistente", async () => {
    await expectCode(
      reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "x", decision: "approved"}),
      "not-found"
    );
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await expectCode(
      reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "maybe"}),
      "invalid-argument"
    );
  });

  it("grava eventos de auditoria do check-in e da decisão", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    const types = events.docs.map((d) => d.get("type")).sort();
    expect(types).toEqual(["checkin", "voter_reviewed"]);
  });
});
