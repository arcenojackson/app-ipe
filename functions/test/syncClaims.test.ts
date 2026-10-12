import {describe, expect, it, vi} from "vitest";
import {syncTeachingClaims} from "../src/teaching/syncClaims";

function fakeAuth(existing?: Record<string, unknown>) {
  return {
    getUser: vi.fn().mockResolvedValue({customClaims: existing}),
    setCustomUserClaims: vi.fn().mockResolvedValue(undefined),
  };
}

describe("syncTeachingClaims", () => {
  it("grava a claim quando o papel é atribuído", async () => {
    const auth = fakeAuth();
    const result = await syncTeachingClaims(auth, "u1", {name: "Ana"}, {name: "Ana", teaching_role: "teacher"});
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {teaching_role: "teacher"});
  });

  it("ignora mudanças que não afetam o acesso", async () => {
    const auth = fakeAuth();
    const result = await syncTeachingClaims(auth, "u1", {name: "Ana"}, {name: "Ana Maria"});
    expect(result).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
    expect(auth.getUser).not.toHaveBeenCalled();
  });

  it("criação de documento sem privilégios não faz nada", async () => {
    const auth = fakeAuth();
    expect(await syncTeachingClaims(auth, "u1", undefined, {name: "Ana", is_admin: false})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("remove a claim ao retirar o papel, preservando claims alheias", async () => {
    const auth = fakeAuth({foo: 1, teaching_role: "teacher"});
    await syncTeachingClaims(auth, "u1", {teaching_role: "teacher"}, {teaching_role: "none"});
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {foo: 1});
  });

  it("papel inválido é ignorado (sem claim)", async () => {
    const auth = fakeAuth();
    expect(await syncTeachingClaims(auth, "u1", {}, {teaching_role: "god"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("limpa as claims quando o documento é apagado", async () => {
    const auth = fakeAuth({admin: true, teaching_role: "curator"});
    const result = await syncTeachingClaims(auth, "u1", {is_admin: true, teaching_role: "curator"}, undefined);
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {});
  });

  it("conta removida do Auth (user-not-found) não lança erro", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("nope"), {code: "auth/user-not-found"}));
    expect(await syncTeachingClaims(auth, "u1", {}, {teaching_role: "teacher"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("outros erros do Auth são propagados", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("boom"), {code: "auth/internal-error"}));
    await expect(syncTeachingClaims(auth, "u1", {}, {teaching_role: "teacher"})).rejects.toThrow("boom");
  });
});
