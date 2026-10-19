import {describe, expect, it, vi} from "vitest";
import {UploadError, uploadFileItem, type UploadDeps} from "./uploadFlow";

const pdf = {name: "aula.pdf", size: 100, type: "application/pdf"};

function makeDeps(overrides: Partial<UploadDeps<typeof pdf>> = {}) {
  const calls: string[] = [];
  const deps: UploadDeps<typeof pdf> = {
    newId: () => "item1",
    now: () => "AGORA",
    uploadObject: vi.fn(async (_path, _file, _type, onProgress) => {
      calls.push("upload");
      onProgress(0.5);
      onProgress(1);
    }),
    createItem: vi.fn(async () => {
      calls.push("create");
    }),
    ...overrides,
  };
  return {deps, calls};
}

describe("uploadFileItem", () => {
  it("envia o arquivo primeiro e só depois cria o documento, com o formato das regras", async () => {
    const {deps, calls} = makeDeps();
    const progress: number[] = [];
    const id = await uploadFileItem(deps, {uid: "t1", parentId: "f1", file: pdf, onProgress: (p) => progress.push(p)});
    expect(id).toBe("item1");
    expect(calls).toEqual(["upload", "create"]);
    expect(progress).toEqual([0.5, 1]);
    expect(deps.uploadObject).toHaveBeenCalledWith("teaching/materials/item1/v1-aula.pdf", pdf, "application/pdf", expect.any(Function));
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({
      type: "file", status: "in_review", authorId: "t1", parentId: "f1", name: "aula.pdf",
      storagePath: "teaching/materials/item1/v1-aula.pdf", createdAt: "AGORA",
    }));
  });

  it("nome do item opcional e limitado a 120 caracteres", async () => {
    const {deps} = makeDeps();
    await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf, name: "Aula especial"});
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({name: "Aula especial"}));
    const long = {name: `${"a".repeat(150)}.pdf`, size: 10, type: "application/pdf"};
    const second = makeDeps();
    await uploadFileItem(second.deps as unknown as UploadDeps<typeof long>, {uid: "t1", parentId: null, file: long});
    const payload = (second.deps.createItem as ReturnType<typeof vi.fn>).mock.calls[0][1] as {name: string};
    expect(payload.name.length).toBeLessThanOrEqual(120);
  });

  it("arquivo inválido não envia nem cria (estágio validate)", async () => {
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: {name: "a.exe", size: 10, type: "application/x-msdownload"}}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha do envio não cria o documento (estágio upload)", async () => {
    const {deps} = makeDeps({uploadObject: vi.fn(async () => {
      throw new Error("rede");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf}).catch((e) => e);
    expect(error.stage).toBe("upload");
    expect(error.message).toBe("Não foi possível enviar o arquivo. Tente novamente.");
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha ao criar o documento depois do envio é sinalizada (estágio create)", async () => {
    const {deps} = makeDeps({createItem: vi.fn(async () => {
      throw new Error("permission-denied");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf}).catch((e) => e);
    expect(error.stage).toBe("create");
    expect(error.message).toBe("O arquivo foi enviado, mas não foi possível registrar o item. Tente novamente.");
  });
});
