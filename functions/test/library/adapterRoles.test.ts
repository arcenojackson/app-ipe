import {describe, expect, it, vi} from "vitest";
import {createAuthRoles} from "../../src/teaching/library/adapterRoles";

describe("createAuthRoles", () => {
  it("currentCuratorIds filtra quem hoje é curador e consulta em lotes de 100", async () => {
    const uids = Array.from({length: 150}, (_, i) => `u${i}`);
    const getUsers = vi.fn(async (ids: Array<{uid: string}>) => ({
      users: ids.map(({uid}) => ({
        uid,
        customClaims: Number(uid.slice(1)) % 50 === 0 ?
          {teaching_role: "curator"} :
          {teaching_role: "teacher"},
      })),
    }));
    const roles = createAuthRoles({getUsers, listUsers: vi.fn()});
    const result = await roles.currentCuratorIds([...uids, ...uids]);
    expect([...result].sort()).toEqual(["u0", "u100", "u50"]);
    expect(getUsers).toHaveBeenCalledTimes(2);
    expect(getUsers.mock.calls[0][0]).toHaveLength(100);
  });

  it("claims ausentes não contam", async () => {
    const getUsers = vi.fn(async () => ({users: [{uid: "a"}, {uid: "b", customClaims: {admin: true}}]}));
    const roles = createAuthRoles({getUsers, listUsers: vi.fn()});
    expect((await roles.currentCuratorIds(["a", "b"])).size).toBe(0);
  });

  it("allCuratorIds percorre todas as páginas", async () => {
    const listUsers = vi.fn()
      .mockResolvedValueOnce({users: [{uid: "a", customClaims: {teaching_role: "curator"}}, {uid: "b"}], pageToken: "t2"})
      .mockResolvedValueOnce({users: [{uid: "c", customClaims: {teaching_role: "curator"}}]});
    const roles = createAuthRoles({getUsers: vi.fn(), listUsers});
    expect(await roles.allCuratorIds()).toEqual(["a", "c"]);
    expect(listUsers).toHaveBeenNthCalledWith(2, 1000, "t2");
  });
});
