import {describe, expect, it} from "vitest";
import {authErrorMessage} from "./errors";

describe("authErrorMessage", () => {
  it("credenciais erradas", () => {
    expect(authErrorMessage("auth/invalid-credential")).toBe("E-mail ou senha incorretos.");
    expect(authErrorMessage("auth/wrong-password")).toBe("E-mail ou senha incorretos.");
    expect(authErrorMessage("auth/user-not-found")).toBe("E-mail ou senha incorretos.");
  });

  it("muitas tentativas, popup fechado e rede", () => {
    expect(authErrorMessage("auth/too-many-requests")).toBe("Muitas tentativas. Tente novamente em alguns minutos.");
    expect(authErrorMessage("auth/popup-closed-by-user")).toBe("Login cancelado.");
    expect(authErrorMessage("auth/network-request-failed")).toBe("Sem conexão. Verifique sua internet.");
  });

  it("código desconhecido cai na mensagem genérica", () => {
    expect(authErrorMessage("auth/qualquer-coisa")).toBe("Não foi possível entrar. Tente novamente.");
  });
});
