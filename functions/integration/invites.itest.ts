import {beforeEach, describe, expect, it, vi} from "vitest";
import {inviteMembers} from "../src/elections/invites";
import {
  DIRECTOR, ELECTION, MEMBER, MEMBER2, MEMBER3, SOCIETY, clearDb, db, seedBase,
} from "./helpers";

const invite = async (uid: string) =>
  (await db.doc(`users/${uid}/election_invites/${ELECTION}`).get()).data();

// m1 recebe push; m2 desativou o tipo; m3 não tem token nem cadastro.
beforeEach(async () => {
  await clearDb();
  await seedBase();
  await db.doc(`users/${MEMBER}`).set({name: "Ana", fcmToken: "tok-m1"});
  await db.doc(`users/${MEMBER2}`).set({
    name: "Bia", fcmToken: "tok-m2", disabled_notifications: ["election_open"],
  });
  await db.doc(`users/${MEMBER3}`).delete();
});

describe("inviteMembers", () => {
  it("grava um convite por membro e manda push só a quem tem token e não desativou", async () => {
    const send = vi.fn().mockResolvedValue({});
    const res = await inviteMembers(db, ELECTION, send);

    expect(res).toEqual({invited: 3, notified: 1});
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) {
      expect(await invite(uid)).toMatchObject({
        electionId: ELECTION, title: "Eleição 2026", societyName: "UMP",
      });
      expect((await invite(uid))?.createdAt).toBeDefined();
    }
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0].tokens).toEqual(["tok-m1"]);
  });

  it("repetir não duplica convites (mesmo documento)", async () => {
    const send = vi.fn().mockResolvedValue({});
    await inviteMembers(db, ELECTION, send);
    await inviteMembers(db, ELECTION, send);

    const snap = await db.collection(`users/${MEMBER}/election_invites`).get();
    expect(snap.size).toBe(1);
  });

  it("sociedade sem membros: nada a fazer e nenhum push", async () => {
    await db.doc(`societies/${SOCIETY}`).update({members: []});
    const send = vi.fn().mockResolvedValue({});

    expect(await inviteMembers(db, ELECTION, send)).toEqual({invited: 0, notified: 0});
    expect(send).not.toHaveBeenCalled();
  });

  it("diretor que não é membro não recebe convite", async () => {
    await inviteMembers(db, ELECTION, vi.fn().mockResolvedValue({}));
    expect(await invite(DIRECTOR)).toBeUndefined();
  });

  it("falha no envio do push não derruba: os convites já estão gravados", async () => {
    const send = vi.fn().mockRejectedValue(new Error("fcm fora do ar"));
    const res = await inviteMembers(db, ELECTION, send);

    expect(res).toEqual({invited: 3, notified: 0});
    expect(await invite(MEMBER)).toBeDefined();
  });
});
