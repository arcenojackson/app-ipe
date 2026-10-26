import {describe, expect, it, vi} from "vitest";
import {
  UploadError,
  resubmitFileItem,
  uploadFileItem,
  type ResubmitDeps,
  type UploadDeps,
} from "./uploadFlow";

const pdf = {name: "aula.pdf", size: 100, type: "application/pdf"};
const TAGS = {typeTags: ["tipo-aulas"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"]};

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
    const id = await uploadFileItem(deps, {uid: "t1", file: pdf, tags: TAGS, onProgress: (p) => progress.push(p)});
    expect(id).toBe("item1");
    expect(calls).toEqual(["upload", "create"]);
    expect(progress).toEqual([0.5, 1]);
    expect(deps.uploadObject).toHaveBeenCalledWith("teaching/materials/item1/v1-aula.pdf", pdf, "application/pdf", expect.any(Function));
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({
      type: "file", status: "in_review", authorId: "t1", parentId: null, name: "aula.pdf", ...TAGS,
      storagePath: "teaching/materials/item1/v1-aula.pdf", createdAt: "AGORA",
    }));
  });

  it("envio sem tag de assunto falha em validate e não envia nada", async () => {
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps, {uid: "t1", file: pdf, tags: {...TAGS, subjectTags: []}}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(error.message).toBe("Escolha pelo menos uma tag de assunto.");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("aceita qualquer tipo de arquivo, como um zip", async () => {
    const {deps} = makeDeps();
    const zip = {name: "material.zip", size: 10, type: "application/zip"};
    await uploadFileItem(deps as unknown as UploadDeps<typeof zip>, {uid: "t1", file: zip, tags: TAGS});
    expect(deps.uploadObject).toHaveBeenCalledWith(expect.any(String), zip, "application/zip", expect.any(Function));
  });

  it("nome do item é opcional e aparado", async () => {
    const {deps} = makeDeps();
    await uploadFileItem(deps, {uid: "t1", file: pdf, tags: TAGS, name: "  Aula especial "});
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({name: "Aula especial"}));
  });

  it.each([
    ["vazio", ""],
    ["só espaços", "   "],
    ["longo demais", "a".repeat(121)],
  ])("nome personalizado %s é recusado antes de enviar (estágio validate)", async (_label, name) => {
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps, {uid: "t1", file: pdf, tags: TAGS, name}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("arquivo com nome longo e sem nome personalizado é recusado, não truncado", async () => {
    const long = {name: `${"a".repeat(130)}.pdf`, size: 10, type: "application/pdf"};
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps as unknown as UploadDeps<typeof long>, {uid: "t1", file: long, tags: TAGS}).catch((e) => e);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
  });

  it("arquivo inválido não envia nem cria (estágio validate)", async () => {
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps, {uid: "t1", tags: TAGS, file: {name: "a.pdf", size: 0, type: "application/pdf"}}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha do envio não cria o documento (estágio upload)", async () => {
    const {deps} = makeDeps({uploadObject: vi.fn(async () => {
      throw new Error("rede");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", file: pdf, tags: TAGS}).catch((e) => e);
    expect(error.stage).toBe("upload");
    expect(error.message).toBe("Não foi possível enviar o arquivo. Tente novamente.");
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha ao criar o documento depois do envio é sinalizada (estágio create)", async () => {
    const {deps} = makeDeps({createItem: vi.fn(async () => {
      throw new Error("permission-denied");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", file: pdf, tags: TAGS}).catch((e) => e);
    expect(error.stage).toBe("create");
    expect(error.message).toBe("O arquivo foi enviado, mas não foi possível registrar o item. Tente novamente.");
  });
});

describe("resubmitFileItem", () => {
  const item = {id: "item1", version: 2};

  function makeResubmit(overrides: Partial<ResubmitDeps<typeof pdf>> = {}) {
    let n = 0;
    const deps: ResubmitDeps<typeof pdf> = {
      newNonce: () => `n${++n}`,
      now: () => "AGORA",
      uploadObject: vi.fn(async (_p, _f, _t, onProgress) => onProgress(1)),
      updateItem: vi.fn(async () => undefined),
      ...overrides,
    };
    return deps;
  }

  it("envia para um caminho novo e atualiza o item com o mesmo caminho", async () => {
    const deps = makeResubmit();
    const progress: number[] = [];
    await resubmitFileItem(deps, {uid: "t1", item, file: pdf, onProgress: (p) => progress.push(p)});
    expect(progress).toEqual([1]);
    expect(deps.uploadObject).toHaveBeenCalledWith("teaching/materials/item1/v3-n1-aula.pdf", pdf, "application/pdf", expect.any(Function));
    expect(deps.updateItem).toHaveBeenCalledWith("item1", expect.objectContaining({
      status: "in_review", version: 3, fileName: "aula.pdf", updatedBy: "t1", updatedAt: "AGORA",
      storagePath: "teaching/materials/item1/v3-n1-aula.pdf",
    }));
  });

  it("depois de falhar a atualização, a nova tentativa usa outro caminho", async () => {
    const update = vi.fn().mockRejectedValueOnce(new Error("rede")).mockResolvedValue(undefined);
    const deps = makeResubmit({updateItem: update});
    const first = await resubmitFileItem(deps, {uid: "t1", item, file: pdf}).catch((e) => e);
    expect(first.stage).toBe("create");
    await resubmitFileItem(deps, {uid: "t1", item, file: pdf});
    const paths = (deps.uploadObject as ReturnType<typeof vi.fn>).mock.calls.map((c) => c[0]);
    expect(paths).toEqual(["teaching/materials/item1/v3-n1-aula.pdf", "teaching/materials/item1/v3-n2-aula.pdf"]);
  });

  it("arquivo inválido não envia nem atualiza (estágio validate)", async () => {
    const deps = makeResubmit();
    const error = await resubmitFileItem(deps, {uid: "t1", item, file: {name: "a.pdf", size: 0, type: "application/pdf"}}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.updateItem).not.toHaveBeenCalled();
  });

  it("reenvio com tags novas inclui tags e tokens no payload", async () => {
    const deps = makeResubmit();
    await resubmitFileItem(deps, {uid: "t1", item, file: pdf, tags: TAGS});
    expect(deps.updateItem).toHaveBeenCalledWith("item1", expect.objectContaining(TAGS));
  });

  it("reenvio com tag de tipo vazio falha em validate", async () => {
    const deps = makeResubmit();
    const error = await resubmitFileItem(deps, {uid: "t1", item, file: pdf, tags: {...TAGS, ageTags: []}}).catch((e) => e);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
  });

  it("falha do envio não atualiza o item (estágio upload)", async () => {
    const deps = makeResubmit({uploadObject: vi.fn(async () => {
      throw new Error("rede");
    })});
    const error = await resubmitFileItem(deps, {uid: "t1", item, file: pdf}).catch((e) => e);
    expect(error.stage).toBe("upload");
    expect(deps.updateItem).not.toHaveBeenCalled();
  });
});
