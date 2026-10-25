import {beforeEach, describe, expect, it, vi} from "vitest";
import {renderDocx, sanitizeDocxLinks, stripActiveContent} from "./docxRender";

const lib = vi.hoisted(() => ({renderAsync: vi.fn()}));
vi.mock("docx-preview", () => lib);

beforeEach(() => {
  lib.renderAsync.mockReset().mockResolvedValue(undefined);
});

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

describe("stripActiveContent", () => {
  it("remove iframe, object, embed, script e frame, mantendo o texto", () => {
    const container = render(
      '<p>texto</p><iframe srcdoc="<script>alert(1)</script>"></iframe><object data="x"></object><embed src="x"><script>alert(1)</script><frameset></frameset>'
    );
    stripActiveContent(container);
    for (const tag of ["iframe", "object", "embed", "script", "frameset"]) {
      expect(container.querySelector(tag)).toBeNull();
    }
    expect(container.textContent).toBe("texto");
  });
});

describe("renderDocx", () => {
  it("não renderiza altChunks (iframes com srcdoc do arquivo) e limpa o que sobrar", async () => {
    lib.renderAsync.mockImplementation(async (_bytes: ArrayBuffer, target: HTMLElement) => {
      target.innerHTML = '<p>ok</p><iframe srcdoc="<script>alert(1)</script>"></iframe><a href="javascript:x">l</a>';
    });
    const container = document.createElement("div");
    await renderDocx(container, new ArrayBuffer(4));
    expect(lib.renderAsync).toHaveBeenCalledWith(
      expect.any(ArrayBuffer), container, undefined, expect.objectContaining({renderAltChunks: false})
    );
    expect(container.querySelector("iframe")).toBeNull();
    expect(container.querySelector("a")?.hasAttribute("href")).toBe(false);
  });
});
