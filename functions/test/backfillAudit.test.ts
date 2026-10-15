import {describe, expect, it} from "vitest";
import {
  formatChangeLine,
  formatClaims,
  formatDryRunSummary,
  formatMissingLine,
  formatMode,
  formatUserLine,
  isAuditedUser,
  isDryRun,
} from "../src/teaching/backfillAudit";

describe("isDryRun / formatMode", () => {
  it("detecta a flag", () => {
    expect(isDryRun(["node", "x.ts", "--dry-run"])).toBe(true);
    expect(isDryRun(["node", "x.ts"])).toBe(false);
  });

  it("formata o modo", () => {
    expect(formatMode(true)).toBe("Modo: DRY-RUN (nada será gravado)");
    expect(formatMode(false)).toBe("Modo: GRAVAÇÃO");
  });
});

describe("isAuditedUser", () => {
  it("inclui admin e papéis válidos", () => {
    expect(isAuditedUser({is_admin: true})).toBe(true);
    expect(isAuditedUser({teaching_role: "teacher"})).toBe(true);
    expect(isAuditedUser({teaching_role: "curator"})).toBe(true);
  });

  it("exclui os demais", () => {
    expect(isAuditedUser({})).toBe(false);
    expect(isAuditedUser({is_admin: "true"})).toBe(false);
    expect(isAuditedUser({is_admin: false})).toBe(false);
    expect(isAuditedUser({teaching_role: "boss"})).toBe(false);
  });
});

describe("formatters", () => {
  it("formata claims", () => {
    expect(formatClaims({})).toBe("{}");
    expect(formatClaims({admin: true, teaching_role: "teacher"})).toBe(
      "{admin: true, teaching_role: teacher}"
    );
  });

  it("formata linha de usuário com valores do documento", () => {
    expect(
      formatUserLine("u1", {
        name: "Ana",
        email: "a@x.com",
        is_admin: true,
        teaching_role: "curator",
      })
    ).toBe(
      "  uid=u1 | nome=Ana | email=a@x.com | is_admin=true | " +
        "teaching_role=curator"
    );
    expect(formatUserLine("u2", {})).toContain("nome=- | email=-");
  });

  it("formata mudança e ausência no Auth", () => {
    expect(
      formatChangeLine("u1", "a@x.com", {admin: true}, {teaching_role: "teacher"})
    ).toBe(
      "  uid=u1 | email=a@x.com | atual={admin: true} | " +
        "desejado={teaching_role: teacher}"
    );
    expect(formatMissingLine("u3", {email: "z@x.com"})).toBe(
      "  uid=u3 | email=z@x.com | sem conta no Auth"
    );
  });

  it("resumo termina avisando que nada foi gravado", () => {
    const lines = formatDryRunSummary({
      read: 10,
      admins: 1,
      teachers: 2,
      curators: 3,
      wouldChange: 4,
      unchanged: 5,
      noAuthAccount: 6,
      failed: 7,
    });
    expect(lines).toContain("  Usuários lidos: 10");
    expect(lines).toContain("  Mudariam: 4");
    expect(lines).toContain("  Sem conta no Auth: 6");
    expect(lines[lines.length - 1]).toBe("DRY-RUN: nada foi gravado.");
  });
});
