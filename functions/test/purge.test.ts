import {describe, expect, it} from "vitest";
import {describePurge} from "../src/teaching/purge";

describe("describePurge", () => {
  it("dry-run lista as quantidades e avisa que nada foi apagado", () => {
    const text = describePurge({items: 12, votes: 30, notifications: 7, objects: 5}, false);
    expect(text).toContain("DRY-RUN");
    expect(text).toContain("12 itens");
    expect(text).toContain("30 votos");
    expect(text).toContain("7 notificações");
    expect(text).toContain("5 arquivos");
    expect(text).toContain("Nada foi apagado");
  });

  it("execução diz o que foi apagado e que teaching_log e tags ficam", () => {
    const text = describePurge({items: 1, votes: 0, notifications: 0, objects: 0}, true);
    expect(text).not.toContain("DRY-RUN");
    expect(text).toContain("1 item");
    expect(text).not.toContain("1 itens");
    expect(text).toContain("Apagado");
    expect(text).toContain("teaching_log");
    expect(text).toContain("teaching_tags");
  });
});
