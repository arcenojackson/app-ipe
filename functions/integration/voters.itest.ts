import {beforeEach, describe, expect, it} from "vitest";
import {checkIn, reviewVoter} from "../src/elections/voters";
import {
  DIRECTOR, OTHER_DIRECTOR, ADMIN, ELECTION, MEMBER, OUTSIDER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const member = {uid: MEMBER, isAnonymous: false, email: "ana@ipe.org"};
const outsider = {uid: OUTSIDER, isAnonymous: false, email: "fora@x.org"};
// Conta Google que nunca usou o app: não existe users/g1.
const google = {
  uid: "g1", isAnonymous: false, email: "gabi@gmail.com", name: "Gabi Google",
};

const voterDoc = async (uid: string) =>
  (await db.doc(`elections/${ELECTION}/voters/${uid}`).get()).data();
const userDoc = async (uid: string) =>
  (await db.doc(`users/${uid}`).get()).data();

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

  it("sessão anônima é recusada", async () => {
    await expectCode(
      checkIn(db, {uid: "anon1", isAnonymous: true}, {electionId: ELECTION, name: "X"}),
      "permission-denied"
    );
    expect(await voterDoc("anon1")).toBeUndefined();
    expect(await userDoc("anon1")).toBeUndefined();
  });

  it("logado que não é da sociedade vira convidado pendente, com nome do cadastro", async () => {
    const res = await checkIn(db, outsider, {electionId: ELECTION});
    expect(res).toEqual({status: "pending", kind: "guest"});
    expect((await voterDoc(OUTSIDER))?.name).toBe("Fora");
    expect((await voterDoc(OUTSIDER))?.email).toBe("fora@x.org");
  });

  it("conta Google nova é cadastrada como usuário novo (pendente) e entra como convidado", async () => {
    const res = await checkIn(db, google, {electionId: ELECTION});
    expect(res).toEqual({status: "pending", kind: "guest"});
    expect(await userDoc("g1")).toEqual({
      id: "g1",
      name: "Gabi Google",
      email: "gabi@gmail.com",
      is_admin: false,
      is_pending: true,
    });
    expect((await voterDoc("g1"))?.name).toBe("Gabi Google");
  });

  it("não sobrescreve o cadastro de quem já é usuário", async () => {
    await checkIn(db, outsider, {electionId: ELECTION});
    const user = await userDoc(OUTSIDER);
    expect(user).toEqual({name: "Fora", is_admin: false});
  });

  it("conta sem nome no token nem no cadastro: pede o nome; com o nome informado, cadastra", async () => {
    const noName = {uid: "g2", isAnonymous: false, email: "sem@nome.org"};
    await expectCode(checkIn(db, noName, {electionId: ELECTION}), "invalid-argument");
    expect(await userDoc("g2")).toBeUndefined();
    const res = await checkIn(db, noName, {electionId: ELECTION, name: " Dona Maria "});
    expect(res).toEqual({status: "pending", kind: "guest"});
    expect((await userDoc("g2"))?.name).toBe("Dona Maria");
    expect((await voterDoc("g2"))?.name).toBe("Dona Maria");
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
    await checkIn(db, google, {electionId: ELECTION});
    await reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "approved"});
    const again = await checkIn(db, {...google, name: "Outro nome"}, {electionId: ELECTION});
    expect(again).toEqual({status: "approved", kind: "guest"});
    expect((await voterDoc("g1"))?.name).toBe("Gabi Google");
  });

  it("chamadas simultâneas criam um único eleitor e um único usuário", async () => {
    const results = await Promise.all([
      checkIn(db, google, {electionId: ELECTION}),
      checkIn(db, google, {electionId: ELECTION}),
    ]);
    expect(results[0]).toEqual(results[1]);
    const snap = await db.collection(`elections/${ELECTION}/voters`).get();
    expect(snap.size).toBe(1);
    expect((await userDoc("g1"))?.is_pending).toBe(true);
  });
});

describe("reviewVoter", () => {
  it("só diretor da eleição aprova (nem membro, nem diretor de outra sociedade, nem admin global)", async () => {
    await checkIn(db, google, {electionId: ELECTION});
    for (const uid of [MEMBER, OTHER_DIRECTOR, ADMIN]) {
      await expectCode(
        reviewVoter(db, uid, {electionId: ELECTION, voterId: "g1", decision: "approved"}),
        "permission-denied"
      );
    }
    expect((await voterDoc("g1"))?.status).toBe("pending");
  });

  it("admin aprova e recusa, registrando quem decidiu", async () => {
    await checkIn(db, google, {electionId: ELECTION});
    await reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "approved"});
    expect((await voterDoc("g1"))?.status).toBe("approved");
    expect((await voterDoc("g1"))?.reviewedBy).toBe(DIRECTOR);
    await reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "rejected"});
    expect((await voterDoc("g1"))?.status).toBe("rejected");
  });

  it("aprovar na eleição não aprova o usuário no app", async () => {
    await checkIn(db, google, {electionId: ELECTION});
    await reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "approved"});
    expect((await userDoc("g1"))?.is_pending).toBe(true);
  });

  it("decisão inválida e eleitor inexistente", async () => {
    await expectCode(
      reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "x", decision: "approved"}),
      "not-found"
    );
    await checkIn(db, google, {electionId: ELECTION});
    await expectCode(
      reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "maybe"}),
      "invalid-argument"
    );
  });

  it("grava eventos de auditoria do check-in e da decisão", async () => {
    await checkIn(db, google, {electionId: ELECTION});
    await reviewVoter(db, DIRECTOR, {electionId: ELECTION, voterId: "g1", decision: "approved"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    const types = events.docs.map((d) => d.get("type")).sort();
    expect(types).toEqual(["checkin", "voter_reviewed"]);
  });
});
