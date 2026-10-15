import {describe, expect, it, vi} from "vitest";
import {
  readSnapshotData,
  syncTeachingClaims,
} from "../src/teaching/syncClaims";

type Data = Record<string, unknown> | undefined;

// Por padrão o documento atual (releitura) coincide com o "after" do evento.
function run(
  auth: ReturnType<typeof fakeAuth>,
  before: Data,
  after: Data,
  ...rest: [Data?]
) {
  const fresh = rest.length > 0 ? rest[0] : after;
  return syncTeachingClaims(auth, "u1", before, after, async () => fresh);
}

function fakeAuth(existing?: Record<string, unknown>) {
  return {
    getUser: vi.fn().mockResolvedValue({customClaims: existing}),
    setCustomUserClaims: vi.fn().mockResolvedValue(undefined),
  };
}

describe("syncTeachingClaims", () => {
  it("grava a claim quando o papel é atribuído", async () => {
    const auth = fakeAuth();
    const result = await run(auth, {name: "Ana"}, {name: "Ana", teaching_role: "teacher"});
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {teaching_role: "teacher"});
  });

  it("ignora mudanças que não afetam o acesso", async () => {
    const auth = fakeAuth();
    const result = await run(auth, {name: "Ana"}, {name: "Ana Maria"});
    expect(result).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
    expect(auth.getUser).not.toHaveBeenCalled();
  });

  it("criação de documento sem privilégios não faz nada", async () => {
    const auth = fakeAuth();
    expect(await run(auth, undefined, {name: "Ana", is_admin: false})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("remove a claim ao retirar o papel, preservando claims alheias", async () => {
    const auth = fakeAuth({foo: 1, teaching_role: "teacher"});
    await run(auth, {teaching_role: "teacher"}, {teaching_role: "none"});
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {foo: 1});
  });

  it("papel inválido é ignorado (sem claim)", async () => {
    const auth = fakeAuth();
    expect(await run(auth, {}, {teaching_role: "god"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("limpa as claims quando o documento é apagado", async () => {
    const auth = fakeAuth({admin: true, teaching_role: "curator"});
    const result = await run(auth, {is_admin: true, teaching_role: "curator"}, undefined);
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {});
  });

  it("conta removida do Auth (user-not-found) não lança erro", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("nope"), {code: "auth/user-not-found"}));
    expect(await run(auth, {}, {teaching_role: "teacher"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("outros erros do Auth são propagados", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("boom"), {code: "auth/internal-error"}));
    await expect(run(auth, {}, {teaching_role: "teacher"})).rejects.toThrow("boom");
  });

  it("evento atrasado que reatribuiria o papel não restaura a claim", async () => {
    const auth = fakeAuth();
    const result = await run(auth, {}, {teaching_role: "teacher"}, {teaching_role: "none"});
    expect(result).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("evento atrasado que limparia usa o documento atual", async () => {
    const auth = fakeAuth({teaching_role: "teacher"});
    const result = await run(auth, {teaching_role: "teacher"}, {teaching_role: "none"}, {teaching_role: "curator"});
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {teaching_role: "curator"});
  });

  it("documento apagado na releitura limpa as claims", async () => {
    const auth = fakeAuth({foo: 1, teaching_role: "teacher"});
    const result = await run(auth, {}, {teaching_role: "teacher"}, undefined);
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {foo: 1});
  });

  it("evento difere mas o Auth já está igual ao documento atual: sem escrita", async () => {
    const auth = fakeAuth({teaching_role: "curator"});
    const result = await run(auth, {}, {teaching_role: "teacher"}, {teaching_role: "curator"});
    expect(result).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("erro na releitura do documento é propagado", async () => {
    const auth = fakeAuth();
    const readUser = vi.fn().mockRejectedValue(new Error("firestore down"));
    await expect(syncTeachingClaims(auth, "u1", {}, {teaching_role: "teacher"}, readUser)).rejects.toThrow("firestore down");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("erro ao gravar claims é propagado", async () => {
    const auth = fakeAuth();
    auth.setCustomUserClaims.mockRejectedValue(new Error("write failed"));
    await expect(run(auth, {}, {teaching_role: "teacher"})).rejects.toThrow("write failed");
  });

  it("o early skip não lê Firestore nem Auth", async () => {
    const auth = fakeAuth();
    const readUser = vi.fn();
    await syncTeachingClaims(auth, "u1", {name: "A"}, {name: "B"}, readUser);
    expect(readUser).not.toHaveBeenCalled();
    expect(auth.getUser).not.toHaveBeenCalled();
  });
});

describe("readSnapshotData", () => {
  it("devolve os dados quando o documento existe", () => {
    expect(readSnapshotData({exists: true, data: () => ({a: 1})})).toEqual({a: 1});
  });
  it("devolve undefined quando o documento não existe", () => {
    expect(readSnapshotData({exists: false, data: () => undefined})).toBeUndefined();
  });
});
