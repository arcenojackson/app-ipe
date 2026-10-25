import {describe, expect, it} from "vitest";
import {
  cancelDeletePayload,
  deleteRequestPayload,
  editTagsPayload,
  movePayload,
  newFilePayload,
  newFolderPayload,
  newLinkPayload,
  renamePayload,
  resubmitFilePayload,
  resubmitLinkPayload,
  voteCommentError,
  votePayload,
} from "./payloads";
import type {ItemTags} from "./tags";

const NOW = "AGORA";
const TAGS: ItemTags = {typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump", "faixa-adultos"]};

describe("criação", () => {
  it("pasta: ativa, versão 1, autor e updatedBy iguais ao uid", () => {
    expect(newFolderPayload({uid: "c1", name: "  Crianças ", parentId: null}, NOW)).toEqual({
      type: "folder", name: "Crianças", parentId: null, authorId: "c1", updatedBy: "c1",
      status: "active", version: 1, createdAt: NOW, updatedAt: NOW,
    });
  });

  it("arquivo: em revisão, sem pasta, com tags e tokens, caminho no Storage com o id do item", () => {
    expect(newFilePayload({
      uid: "t1", itemId: "abc", name: "Fé", tags: TAGS,
      fileName: "aula/1.pdf", contentType: "application/pdf", size: 1000,
    }, NOW)).toEqual({
      type: "file", name: "Fé", parentId: null, authorId: "t1", updatedBy: "t1",
      status: "in_review", version: 1, fileName: "aula_1.pdf", contentType: "application/pdf",
      size: 1000, storagePath: "teaching/materials/abc/v1-aula_1.pdf",
      ...TAGS, searchTokens: ["fe"], createdAt: NOW, updatedAt: NOW,
    });
  });

  it("link: em revisão, com tags; description só quando preenchida", () => {
    const withDescription = newLinkPayload({uid: "t1", name: "Livro", url: " https://x.org ", description: " bom ", tags: TAGS}, NOW);
    expect(withDescription).toMatchObject({
      type: "link", status: "in_review", url: "https://x.org", description: "bom", parentId: null, ...TAGS,
    });
    expect(withDescription.searchTokens).toContain("livro");
    const without = newLinkPayload({uid: "t1", name: "Livro", url: "https://x.org", description: "  ", tags: TAGS}, NOW);
    expect(Object.keys(without)).not.toContain("description");
  });

  it("nenhum construtor de criação inclui campos que só a Function escreve", () => {
    const docs = [
      newFolderPayload({uid: "c1", name: "A", parentId: null}, NOW),
      newFilePayload({uid: "t1", itemId: "i", name: "A", fileName: "a.pdf", contentType: "application/pdf", size: 1, tags: TAGS}, NOW),
      newLinkPayload({uid: "t1", name: "A", url: "https://x.org", tags: TAGS}, NOW),
    ];
    for (const doc of docs) {
      for (const forbidden of ["deleteRequest", "deleteRequested", "deleting", "returnComment", "returnedBy"]) {
        expect(Object.keys(doc)).not.toContain(forbidden);
      }
    }
  });
});

describe("organização e exclusão", () => {
  it("renomear e mover mexem só nos campos permitidos", () => {
    expect(renamePayload({uid: "c1", name: " Novo "}, NOW)).toEqual({
      name: "Novo", searchTokens: ["no", "nov", "novo"], updatedBy: "c1", updatedAt: NOW,
    });
    expect(movePayload({uid: "c1", parentId: null}, NOW)).toEqual({parentId: null, updatedBy: "c1", updatedAt: NOW});
  });

  it("editar tags mexe só nos três campos de tag e no autor da alteração", () => {
    expect(editTagsPayload({uid: "c1", tags: TAGS}, NOW)).toEqual({...TAGS, updatedBy: "c1", updatedAt: NOW});
    expect(Object.keys(editTagsPayload({uid: "c1", tags: TAGS}, NOW))).not.toContain("searchTokens");
  });

  it("pedido de exclusão: uuid recebido, quem pediu, motivo opcional", () => {
    expect(deleteRequestPayload({uid: "c1", requestId: "uuid-1", reason: " obsoleto "}, NOW)).toEqual({
      deleteRequested: true,
      deleteRequest: {id: "uuid-1", requestedBy: "c1", requestedAt: NOW, reason: "obsoleto"},
      updatedBy: "c1", updatedAt: NOW,
    });
    const noReason = deleteRequestPayload({uid: "c1", requestId: "uuid-2"}, NOW);
    expect(Object.keys(noReason.deleteRequest)).toEqual(["id", "requestedBy", "requestedAt"]);
  });

  it("cancelar o pedido zera os dois campos", () => {
    expect(cancelDeletePayload({uid: "c1"}, NOW)).toEqual({deleteRequested: false, deleteRequest: null, updatedBy: "c1", updatedAt: NOW});
  });
});

describe("reenvio", () => {
  it("arquivo: versão + 1, novo caminho, volta para em revisão", () => {
    expect(resubmitFilePayload({uid: "t1", itemId: "abc", currentVersion: 1, fileName: "novo.pdf", contentType: "application/pdf", size: 5}, NOW)).toEqual({
      status: "in_review", version: 2, fileName: "novo.pdf", contentType: "application/pdf", size: 5,
      storagePath: "teaching/materials/abc/v2-novo.pdf", updatedBy: "t1", updatedAt: NOW,
    });
  });

  it("arquivo com novo nome do item inclui name", () => {
    expect(resubmitFilePayload({uid: "t1", itemId: "abc", currentVersion: 2, fileName: "n.pdf", contentType: "application/pdf", size: 5, name: " Aula nova "}, NOW)).toMatchObject({name: "Aula nova", version: 3});
  });

  it("link: versão + 1 e nova url", () => {
    expect(resubmitLinkPayload({uid: "t1", currentVersion: 1, url: " https://novo.org "}, NOW)).toEqual({
      status: "in_review", version: 2, url: "https://novo.org", updatedBy: "t1", updatedAt: NOW,
    });
  });
});

describe("reenvio com tags", () => {
  it("arquivo: inclui tags só quando vierem; name recalcula searchTokens", () => {
    const withTags = resubmitFilePayload({
      uid: "t1", itemId: "i", currentVersion: 1, fileName: "b.pdf", contentType: "application/pdf", size: 5,
      name: "Novo nome", tags: TAGS,
    }, NOW);
    expect(withTags).toMatchObject({...TAGS, name: "Novo nome", searchTokens: ["no", "nov", "novo", "nom", "nome"]});
    const without = resubmitFilePayload({
      uid: "t1", itemId: "i", currentVersion: 1, fileName: "b.pdf", contentType: "application/pdf", size: 5,
    }, NOW);
    for (const key of ["typeTags", "subjectTags", "ageTags", "searchTokens"]) expect(Object.keys(without)).not.toContain(key);
  });

  it("link: inclui tags quando vierem", () => {
    const payload = resubmitLinkPayload({uid: "t1", currentVersion: 1, url: "https://novo.org", tags: TAGS}, NOW);
    expect(payload).toMatchObject(TAGS);
  });
});

describe("votos", () => {
  it("voto de publicação leva a versão e nunca o requestId", () => {
    expect(votePayload({uid: "c1", action: "approve", version: 2, requestId: "x"}, NOW)).toEqual({
      voterId: "c1", action: "approve", version: 2, createdAt: NOW,
    });
    expect(votePayload({uid: "c1", action: "return", version: 1, comment: " Falta a referência "}, NOW)).toEqual({
      voterId: "c1", action: "return", version: 1, comment: "Falta a referência", createdAt: NOW,
    });
  });

  it("voto de exclusão leva o requestId e nunca a versão", () => {
    expect(votePayload({uid: "c2", action: "delete_approve", requestId: "r1", version: 3}, NOW)).toEqual({
      voterId: "c2", action: "delete_approve", requestId: "r1", createdAt: NOW,
    });
    expect(votePayload({uid: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado"}, NOW)).toEqual({
      voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: NOW,
    });
  });

  it("voto de exclusão sem requestId lança erro", () => {
    const message = "votePayload: requestId é obrigatório em votos de exclusão.";
    expect(() => votePayload({uid: "c1", action: "delete_approve"}, NOW)).toThrow(message);
    expect(() => votePayload({uid: "c1", action: "delete_refuse", requestId: "", comment: "x"}, NOW)).toThrow(message);
  });

  it("voto de publicação sem version lança erro", () => {
    const message = "votePayload: version é obrigatório em votos de publicação.";
    expect(() => votePayload({uid: "c1", action: "approve"}, NOW)).toThrow(message);
    expect(() => votePayload({uid: "c1", action: "reject", version: undefined, comment: "x"}, NOW)).toThrow(message);
    expect(() => votePayload({uid: "c1", action: "return", requestId: "r1", comment: "x"}, NOW)).toThrow(message);
  });

  it("comentário só com espaços é omitido", () => {
    expect(votePayload({uid: "c1", action: "approve", version: 1, comment: "   "}, NOW)).toEqual({
      voterId: "c1", action: "approve", version: 1, createdAt: NOW,
    });
    expect(votePayload({uid: "c1", action: "delete_approve", requestId: "r1", comment: "  "}, NOW)).toEqual({
      voterId: "c1", action: "delete_approve", requestId: "r1", createdAt: NOW,
    });
  });

  it("version 0 é aceito (typeof number)", () => {
    expect(votePayload({uid: "c1", action: "approve", version: 0}, NOW)).toEqual({
      voterId: "c1", action: "approve", version: 0, createdAt: NOW,
    });
  });

  it("comentário é obrigatório em devolver, rejeitar e recusar exclusão", () => {
    expect(voteCommentError("approve", undefined)).toBeNull();
    expect(voteCommentError("delete_approve", "")).toBeNull();
    for (const action of ["return", "reject", "delete_refuse"] as const) {
      expect(voteCommentError(action, "   ")).toBe("Escreva um comentário.");
      expect(voteCommentError(action, undefined)).toBe("Escreva um comentário.");
      expect(voteCommentError(action, "x".repeat(1001))).toBe("O comentário pode ter no máximo 1000 caracteres.");
      expect(voteCommentError(action, "ok")).toBeNull();
    }
  });
});
