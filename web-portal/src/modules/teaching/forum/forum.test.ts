import {describe, expect, it} from "vitest";
import {toComment, toTopic} from "./convert";
import {linkify} from "./linkify";
import {
  commentEditPatch,
  newCommentPayload,
  newTopicPayload,
  topicEditPatch,
  validateCommentInput,
  validateTopicInput,
} from "./payloads";
import {commentPermissions, topicPermissions} from "./permissions";
import {buildTree} from "./tree";
import type {Comment, Topic} from "./types";

const TS = "AGORA";
const ref = {kind: "library" as const, id: "1", label: "Doc"};

const topic = (extra: Partial<Topic> = {}): Topic => ({
  id: "t", title: "Título", body: "Corpo", authorUid: "u1", authorName: "Ana",
  tagIds: [], refs: [], pinned: false, locked: false, deleted: false,
  createdAt: 1, updatedAt: 1, lastActivityAt: 1, commentCount: 0, ...extra,
});

const comment = (extra: Partial<Comment> = {}): Comment => ({
  id: "c", topicId: "t", body: "Oi", authorUid: "u2", authorName: "Bia",
  parentId: null, depth: 1, refs: [], score: 0, deleted: false, createdAt: 1, ...extra,
});

const viewer = (uid: string, role: "teacher" | "curator" | "admin" = "teacher") => ({
  uid, isCurator: role === "curator", isAdmin: role === "admin",
});

describe("converters", () => {
  it("toTopic converte e ignora documentos incompletos", () => {
    const t = toTopic("a", {
      title: "T", body: "B", authorUid: "u", tagIds: ["x", 1], pinned: true,
      refs: [ref, {kind: "x", id: "1", label: "L"}], createdAt: {toMillis: () => 5},
    });
    expect(t).toMatchObject({id: "a", tagIds: ["x"], pinned: true, createdAt: 5, commentCount: 0, refs: [ref]});
    expect(toTopic("b", {title: "T"})).toBeNull();
  });

  it("toComment exige profundidade 1 a 3", () => {
    expect(toComment("t", "c", {body: "B", authorUid: "u", depth: 2, parentId: "p"}))
      .toMatchObject({topicId: "t", depth: 2, parentId: "p", score: 0});
    expect(toComment("t", "c", {body: "B", authorUid: "u", depth: 4})).toBeNull();
    expect(toComment("t", "c", {body: "B", depth: 1})).toBeNull();
  });
});

describe("validação", () => {
  const ok = {title: "abc", body: "x", tagIds: [], refs: []};

  it("aceita os limites exatos", () => {
    expect(validateTopicInput({...ok, title: "x".repeat(120), body: "y".repeat(5000),
      tagIds: ["a", "b", "c"], refs: [ref, ref, ref]})).toBeNull();
    expect(validateTopicInput(ok)).toBeNull();
  });

  it("rejeita fora dos limites", () => {
    expect(validateTopicInput({...ok, title: "ab"})).toMatch(/título/);
    expect(validateTopicInput({...ok, title: " a "})).toMatch(/título/);
    expect(validateTopicInput({...ok, title: "x".repeat(121)})).toMatch(/título/);
    expect(validateTopicInput({...ok, body: "  "})).toMatch(/mensagem/);
    expect(validateTopicInput({...ok, body: "y".repeat(5001)})).toMatch(/mensagem/);
    expect(validateTopicInput({...ok, tagIds: ["a", "b", "c", "d"]})).toMatch(/assuntos/);
    expect(validateTopicInput({...ok, refs: [ref, ref, ref, ref]})).toMatch(/Cite/);
    expect(validateCommentInput({body: "", refs: []})).toMatch(/mensagem/);
    expect(validateCommentInput({body: "ok", refs: []})).toBeNull();
  });
});

describe("payloads", () => {
  it("tópico novo traz moderação desligada, contador zero e tokens do título", () => {
    const p = newTopicPayload({title: " Aula três ", body: " B ", tagIds: ["a"], refs: []},
      {uid: "u1", name: "Ana"}, TS);
    expect(p).toMatchObject({
      title: "Aula três", body: "B", authorUid: "u1", authorName: "Ana", pinned: false,
      locked: false, deleted: false, commentCount: 0, createdAt: TS, updatedAt: TS, lastActivityAt: TS,
    });
    expect(p.searchTokens).toContain("au");
    expect(p.searchTokens).toContain("tres");
  });

  it("comentário calcula profundidade e zera score", () => {
    const author = {uid: "u2", name: "Bia"};
    expect(newCommentPayload({body: "x", refs: []}, author, null, TS))
      .toMatchObject({parentId: null, depth: 1, score: 0, deleted: false, createdAt: TS});
    expect(newCommentPayload({body: "x", refs: []}, author, comment({id: "p", depth: 2}), TS))
      .toMatchObject({parentId: "p", depth: 3});
    expect(() => newCommentPayload({body: "x", refs: []}, author, comment({depth: 3}), TS)).toThrow();
  });

  it("edição só carrega os campos editáveis", () => {
    expect(Object.keys(topicEditPatch({title: "abc", body: "b", tagIds: [], refs: []}, TS)).sort())
      .toEqual(["body", "editedAt", "refs", "searchTokens", "tagIds", "title", "updatedAt"]);
    expect(commentEditPatch({body: " x ", refs: []}, TS)).toEqual({body: "x", refs: [], editedAt: TS});
  });
});

describe("buildTree", () => {
  it("aninha, ordena por data e põe órfãos na raiz", () => {
    const tree = buildTree([
      comment({id: "b", createdAt: 3}),
      comment({id: "a", createdAt: 1}),
      comment({id: "a1", parentId: "a", depth: 2, createdAt: 2}),
      comment({id: "a11", parentId: "a1", depth: 3, createdAt: 4}),
      comment({id: "orf", parentId: "sumiu", depth: 2, createdAt: 5}),
    ]);
    expect(tree.map((n) => n.comment.id)).toEqual(["a", "b", "orf"]);
    expect(tree[0].children[0].comment.id).toBe("a1");
    expect(tree[0].children[0].children[0].comment.id).toBe("a11");
  });
});

describe("permissões", () => {
  it("comentário: autor edita e apaga; moderador só apaga; outro professor nada", () => {
    const c = comment({authorUid: "u2"});
    expect(commentPermissions(c, topic(), viewer("u2"))).toMatchObject({canEdit: true, canDelete: true, canVote: false});
    expect(commentPermissions(c, topic(), viewer("u3", "curator"))).toMatchObject({canEdit: false, canDelete: true, canVote: true});
    expect(commentPermissions(c, topic(), viewer("u4", "admin"))).toMatchObject({canEdit: false, canDelete: true});
    expect(commentPermissions(c, topic(), viewer("u5"))).toMatchObject({canEdit: false, canDelete: false, canVote: true});
  });

  it("não responde nem vota em nível 3, removido, tópico trancado ou removido", () => {
    expect(commentPermissions(comment({depth: 3}), topic(), viewer("u5")).canReply).toBe(false);
    expect(commentPermissions(comment({depth: 2}), topic(), viewer("u5")).canReply).toBe(true);
    const dead = commentPermissions(comment({deleted: true}), topic(), viewer("u5"));
    expect(dead).toEqual({canReply: false, canVote: false, canEdit: false, canDelete: false});
    for (const t of [topic({locked: true}), topic({deleted: true})]) {
      expect(commentPermissions(comment(), t, viewer("u5"))).toMatchObject({canReply: false, canVote: false});
    }
  });

  it("tópico: só moderador fixa e tranca; corpo de removido só para autor/moderador", () => {
    expect(topicPermissions(topic(), viewer("u5"))).toMatchObject({canPin: false, canLock: false, canComment: true});
    expect(topicPermissions(topic(), viewer("u9", "curator"))).toMatchObject({canPin: true, canLock: true, canDelete: true});
    expect(topicPermissions(topic(), viewer("u1"))).toMatchObject({canEdit: true, canDelete: true, canPin: false});
    const gone = topic({deleted: true});
    expect(topicPermissions(gone, viewer("u5")).visibleBody).toBe(false);
    expect(topicPermissions(gone, viewer("u1")).visibleBody).toBe(true);
    expect(topicPermissions(gone, viewer("u9", "admin")).visibleBody).toBe(true);
    expect(topicPermissions(topic({locked: true}), viewer("u5")).canComment).toBe(false);
  });
});

describe("linkify", () => {
  it("só http(s) vira link e a pontuação final fica de fora", () => {
    expect(linkify("veja https://a.com/x, e <script>alert(1)</script>")).toEqual([
      {type: "text", value: "veja "},
      {type: "link", value: "https://a.com/x"},
      {type: "text", value: ", e <script>alert(1)</script>"},
    ]);
    expect(linkify("javascript:alert(1)")).toEqual([{type: "text", value: "javascript:alert(1)"}]);
    expect(linkify("")).toEqual([]);
  });
});
