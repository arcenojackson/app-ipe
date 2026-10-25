import {describe, expect, it} from "vitest";
import {sanitizeDocxLinks} from "./docxRender";

function render(html: string): HTMLElement {
  const container = document.createElement("div");
  container.innerHTML = html;
  return container;
}

const anchors = (container: HTMLElement) => [...container.querySelectorAll("a")];

describe("sanitizeDocxLinks", () => {
  it("javascript: e data: perdem o href", () => {
    const container = render(
      '<a href="javascript:alert(1)">a</a><a href="data:text/html,x">b</a><a href="vbscript:x">c</a>'
    );
    sanitizeDocxLinks(container);
    for (const a of anchors(container)) expect(a.hasAttribute("href")).toBe(false);
  });

  it("não se deixa enganar por caixa, espaços ou quebras dentro do esquema", () => {
    const container = render(
      '<a href="JaVaScRiPt:alert(1)">a</a><a href="  javascript:alert(1)">b</a><a href="java&#9;script:alert(1)">c</a><a href="java&#10;script:alert(1)">d</a>'
    );
    sanitizeDocxLinks(container);
    for (const a of anchors(container)) expect(a.hasAttribute("href")).toBe(false);
  });

  it("https e mailto mantêm o href e abrem em nova aba com rel seguro", () => {
    const container = render('<a href="https://x.org">a</a><a href="mailto:a@b.c">b</a>');
    sanitizeDocxLinks(container);
    for (const a of anchors(container)) {
      expect(a.hasAttribute("href")).toBe(true);
      expect(a.getAttribute("target")).toBe("_blank");
      expect(a.getAttribute("rel")).toBe("noopener noreferrer");
    }
  });

  it("âncora sem href não é alterada", () => {
    const container = render("<a>x</a>");
    sanitizeDocxLinks(container);
    expect(container.querySelector("a")?.hasAttribute("target")).toBe(false);
  });
});
