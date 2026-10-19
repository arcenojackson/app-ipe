import {describe, expect, it} from "vitest";
import {
  deleteExecutedMessage,
  deleteRefusedMessage,
  deleteRequestedMessage,
  moveRevertedMessage,
  publishedMessage,
  rejectedMessage,
  returnedMessage,
  reviewRequestedMessage,
} from "../../src/teaching/library/messages";
import {makeItem} from "./fakes";

const item = makeItem({id: "i1", name: "Aula 1"});

describe("mensagens (pt-BR)", () => {
  it("novo envio e reenvio", () => {
    expect(reviewRequestedMessage(item, false)).toEqual({
      title: "Novo material para revisar",
      body: "\"Aula 1\" aguarda a sua revisão.",
    });
    expect(reviewRequestedMessage(item, true).title).toBe("Material reenviado para revisão");
  });

  it("publicado, devolvido e rejeitado", () => {
    expect(publishedMessage(item).title).toBe("Material publicado");
    expect(returnedMessage(item, "Falta a referência").body).toBe("\"Aula 1\": Falta a referência");
    expect(rejectedMessage(item, ["Fora do escopo", "Duplicado"]).body).toBe(
      "\"Aula 1\" foi rejeitado pelos curadores. Motivo: Fora do escopo | Duplicado"
    );
    expect(rejectedMessage(item, []).body).toBe("\"Aula 1\" foi rejeitado pelos curadores.");
  });

  it("pedido de exclusão, recusa, execução e movimento desfeito", () => {
    expect(deleteRequestedMessage(item).title).toBe("Pedido de exclusão");
    expect(deleteRefusedMessage(item, "Ainda é usado").body).toBe("A exclusão de \"Aula 1\" foi recusada: Ainda é usado");
    expect(deleteExecutedMessage(item).title).toBe("Exclusão concluída");
    expect(moveRevertedMessage(item).title).toBe("Movimento desfeito");
  });

  it("textos longos são cortados em 200 caracteres", () => {
    const long = makeItem({id: "i2", name: "x".repeat(300)});
    expect(publishedMessage(long).body.length).toBeLessThanOrEqual(200);
  });
});
