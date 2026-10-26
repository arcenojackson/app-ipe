import {describe, expect, it} from "vitest";
import {
  processCommentCreated,
  processCommentUpdated,
} from "../../src/teaching/forum/processComment";
import {processVoteWritten} from "../../src/teaching/forum/processVote";
import type {
  CommentData,
  ForumDeps,
  ForumNotification,
  TopicData,
  TopicStats,
} from "../../src/teaching/forum/types";

const comment = (extra: Partial<CommentData> = {}): CommentData => ({
  authorUid: "u2", authorName: "Tiago", parentId: null, body: "Olá",
  deleted: false, createdAt: new Date(1000), ...extra,
});

const setup = (
  comments: Record<string, CommentData>,
  topic: TopicData | null = {authorUid: "u1", title: "T", deleted: false},
  votes: Record<string, number[]> = {}
) => {
  const sent = new Map<string, ForumNotification>();
  const stats: TopicStats[] = [];
  const scores: Record<string, number> = {};
  const deps: ForumDeps = {
    db: {
      getTopic: async () => topic,
      getComment: async (_t, id) => comments[id] ?? null,
      countActiveComments: async () =>
        Object.values(comments).filter((c) => !c.deleted).length,
      sumVotes: async (_t, id) => (votes[id] ?? []).reduce((a, b) => a + b, 0),
      setTopicStats: async (_t, s) => {
        stats.push(s);
      },
      setCommentScore: async (_t, id, score) => {
        scores[id] = score;
      },
    },
    notifier: {notify: async (n) => {
      sent.set(n.id, n);
    }},
  };
  return {deps, sent, stats, scores};
};

describe("processCommentCreated", () => {
  it("atualiza contador e atividade e notifica o autor do tópico", async () => {
    const {deps, sent, stats} = setup({c1: comment()});
    await processCommentCreated(deps, "t", "c1");
    expect(stats).toEqual([{commentCount: 1, lastActivityAt: new Date(1000)}]);
    expect(sent.get("forum_reply_c1")).toMatchObject({
      toUid: "u1", topicId: "t", commentId: "c1",
    });
  });

  it("resposta notifica só o autor do comentário-pai", async () => {
    const {deps, sent} = setup({
      p: comment({authorUid: "u3"}),
      c1: comment({parentId: "p"}),
    });
    await processCommentCreated(deps, "t", "c1");
    expect([...sent.values()].map((n) => n.toUid)).toEqual(["u3"]);
  });

  it("não notifica quem responde a si mesmo", async () => {
    const {deps, sent} = setup({c1: comment({authorUid: "u1"})});
    await processCommentCreated(deps, "t", "c1");
    expect(sent.size).toBe(0);
    const again = setup({
      p: comment({authorUid: "u2"}),
      c1: comment({parentId: "p", authorUid: "u2"}),
    });
    await processCommentCreated(again.deps, "t", "c1");
    expect(again.sent.size).toBe(0);
  });

  it("rodar duas vezes dá o mesmo resultado", async () => {
    const {deps, sent, stats} = setup({c1: comment()});
    await processCommentCreated(deps, "t", "c1");
    await processCommentCreated(deps, "t", "c1");
    expect(stats[0]).toEqual(stats[1]);
    expect(sent.size).toBe(1);
  });

  it("trunca o corpo na notificação", async () => {
    const {deps, sent} = setup({c1: comment({body: "x".repeat(300)})});
    await processCommentCreated(deps, "t", "c1");
    expect(sent.get("forum_reply_c1")!.body.length).toBeLessThan(130);
  });

  it("ignora tópico removido, inexistente ou comentário inexistente", async () => {
    const gone = setup({c1: comment()}, {authorUid: "u1", title: "T", deleted: true});
    await processCommentCreated(gone.deps, "t", "c1");
    const none = setup({c1: comment()}, null);
    await processCommentCreated(none.deps, "t", "c1");
    const missing = setup({});
    await processCommentCreated(missing.deps, "t", "zzz");
    for (const s of [gone, none, missing]) {
      expect(s.stats).toEqual([]);
      expect(s.sent.size).toBe(0);
    }
  });
});

describe("processCommentUpdated", () => {
  it("recalcula o contador quando o comentário é removido", async () => {
    const {deps, stats} = setup({a: comment(), b: comment({deleted: true})});
    await processCommentUpdated(deps, "t", comment(), comment({deleted: true}));
    expect(stats).toEqual([{commentCount: 1}]);
  });

  it("ignora edição de texto e remoção já feita", async () => {
    const {deps, stats} = setup({a: comment()});
    await processCommentUpdated(deps, "t", comment(), comment({body: "x"}));
    await processCommentUpdated(
      deps, "t", comment({deleted: true}), comment({deleted: true}));
    expect(stats).toEqual([]);
  });
});

describe("processVoteWritten", () => {
  it("grava a soma dos votos e é idempotente", async () => {
    const {deps, scores} = setup({c1: comment()}, undefined, {c1: [1, 1, -1]});
    await processVoteWritten(deps, "t", "c1");
    await processVoteWritten(deps, "t", "c1");
    expect(scores).toEqual({c1: 1});
  });

  it("voto retirado reduz e comentário inexistente é ignorado", async () => {
    const {deps, scores} = setup({c1: comment()}, undefined, {c1: []});
    await processVoteWritten(deps, "t", "c1");
    await processVoteWritten(deps, "t", "nope");
    expect(scores).toEqual({c1: 0});
  });
});
