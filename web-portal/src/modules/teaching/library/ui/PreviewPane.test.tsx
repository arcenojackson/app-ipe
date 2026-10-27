import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryItem} from "../types";
import {PreviewPane} from "./PreviewPane";

const bytesHook = vi.hoisted(() => ({useFileBytes: vi.fn()}));
vi.mock("../useFileBytes", () => bytesHook);
const pdf = vi.hoisted(() => ({renderPdf: vi.fn()}));
vi.mock("../pdfRender", () => pdf);
const docx = vi.hoisted(() => ({renderDocx: vi.fn()}));
vi.mock("../docxRender", () => docx);
const storage = vi.hoisted(() => ({downloadUrl: vi.fn()}));
vi.mock("../storageAccess", () => storage);

const DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

const file = (over: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "i1", type: "file", name: "Aula 1", parentId: null, authorId: "t1", status: "in_review", version: 1,
  fileName: "aula.pdf", contentType: "application/pdf", size: 2048, storagePath: "teaching/materials/i1/v1-aula.pdf", ...over,
});

const ready = (bytes = new ArrayBuffer(8)) => ({bytes, loading: false, error: null});

beforeEach(() => {
  bytesHook.useFileBytes.mockReset().mockReturnValue(ready());
  pdf.renderPdf.mockReset().mockResolvedValue(() => undefined);
  docx.renderDocx.mockReset().mockResolvedValue(() => undefined);
  storage.downloadUrl.mockReset().mockResolvedValue("https://files.example/a");
  URL.createObjectURL = vi.fn(() => "blob:img");
  URL.revokeObjectURL = vi.fn();
});

describe("PreviewPane", () => {
  it("PDF: lê os bytes e chama renderPdf com o container", async () => {
    const bytes = new ArrayBuffer(8);
    bytesHook.useFileBytes.mockReturnValue(ready(bytes));
    render(<PreviewPane item={file()} />);
    await waitFor(() => expect(pdf.renderPdf).toHaveBeenCalledWith(expect.any(HTMLElement), bytes));
    expect(bytesHook.useFileBytes).toHaveBeenCalledWith("teaching/materials/i1/v1-aula.pdf", true);
  });

  it("DOCX (também pelo nome): chama renderDocx", async () => {
    render(<PreviewPane item={file({contentType: DOCX, fileName: "a.docx"})} />);
    await waitFor(() => expect(docx.renderDocx).toHaveBeenCalledWith(expect.any(HTMLElement), expect.any(ArrayBuffer)));
    expect(pdf.renderPdf).not.toHaveBeenCalled();
  });

  it("imagem: <img> com blob URL, revogada ao desmontar", async () => {
    const {unmount} = render(<PreviewPane item={file({contentType: "image/png", fileName: "a.png"})} />);
    expect(await screen.findByAltText("Aula 1")).toHaveAttribute("src", "blob:img");
    unmount();
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:img");
  });

  it("enquanto carrega mostra Carregando visualização…", () => {
    bytesHook.useFileBytes.mockReturnValue({bytes: null, loading: true, error: null});
    render(<PreviewPane item={file()} />);
    expect(screen.getByText("Carregando visualização…")).toBeInTheDocument();
  });

  it("zip mostra nome, tipo, tamanho e Baixar, sem baixar os bytes", () => {
    render(<PreviewPane item={file({contentType: "application/zip", fileName: "material.zip", size: 6 * 1024})} />);
    expect(screen.getByText("material.zip")).toBeInTheDocument();
    expect(screen.getByText("application/zip")).toBeInTheDocument();
    expect(screen.getByText("6 KB")).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Baixar"})).toBeInTheDocument();
    expect(bytesHook.useFileBytes).toHaveBeenLastCalledWith("teaching/materials/i1/v1-aula.pdf", false);
  });

  it("arquivo de 60 MB não é baixado para visualizar", () => {
    render(<PreviewPane item={file({size: 60 * 1024 * 1024})} />);
    expect(screen.getByText("Arquivo grande demais para visualizar aqui.")).toBeInTheDocument();
    expect(bytesHook.useFileBytes).toHaveBeenLastCalledWith("teaching/materials/i1/v1-aula.pdf", false);
    expect(pdf.renderPdf).not.toHaveBeenCalled();
  });

  it("erro do renderizador mostra aviso e mantém o botão Baixar", async () => {
    pdf.renderPdf.mockRejectedValue(new Error("senha"));
    render(<PreviewPane item={file()} />);
    expect(await screen.findByText("Não foi possível exibir o arquivo. Baixe para abri-lo.")).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Baixar"})).toBeInTheDocument();
  });

  it("erro ao ler os bytes mostra o mesmo aviso", () => {
    bytesHook.useFileBytes.mockReturnValue({bytes: null, loading: false, error: "falhou"});
    render(<PreviewPane item={file()} />);
    expect(screen.getByText("Não foi possível exibir o arquivo. Baixe para abri-lo.")).toBeInTheDocument();
  });

  it("permissão negada na leitura mostra mensagem específica", () => {
    bytesHook.useFileBytes.mockReturnValue({bytes: null, loading: false, error: "Sem permissão para este arquivo."});
    render(<PreviewPane item={file()} />);
    expect(screen.getByText("Sem permissão para este arquivo.")).toBeInTheDocument();
  });

  it("Baixar com permissão negada ou arquivo inexistente mostra o motivo", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    storage.downloadUrl.mockRejectedValue({code: "storage/unauthorized"});
    render(<PreviewPane item={file({contentType: "application/zip", fileName: "a.zip"})} />);
    fireEvent.click(screen.getByRole("button", {name: "Baixar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Sem permissão para este arquivo.");
    storage.downloadUrl.mockRejectedValue({code: "storage/object-not-found"});
    fireEvent.click(screen.getByRole("button", {name: "Baixar"}));
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("Arquivo não encontrado."));
  });

  it("link não renderiza pré-visualização", () => {
    const {container} = render(<PreviewPane item={file({type: "link", url: "https://x.org"})} />);
    expect(container).toBeEmptyDOMElement();
  });

  it("Baixar obtém a URL e abre em nova aba com rel seguro", async () => {
    const open = vi.spyOn(window, "open").mockReturnValue(null);
    render(<PreviewPane item={file({contentType: "application/zip", fileName: "a.zip"})} />);
    fireEvent.click(screen.getByRole("button", {name: "Baixar"}));
    await waitFor(() => expect(open).toHaveBeenCalledWith("https://files.example/a", "_blank", "noopener,noreferrer"));
    expect(storage.downloadUrl).toHaveBeenCalledWith("teaching/materials/i1/v1-aula.pdf");
    open.mockRestore();
  });

  it("falha ao obter a URL de download mostra alerta", async () => {
    storage.downloadUrl.mockRejectedValue(new Error("x"));
    render(<PreviewPane item={file({contentType: "application/zip", fileName: "a.zip"})} />);
    fireEvent.click(screen.getByRole("button", {name: "Baixar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível baixar o arquivo.");
  });
});
