import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {UploadError} from "../uploadFlow";
import {UploadPanel} from "./UploadPanel";

const mutations = vi.hoisted(() => ({uploadFile: vi.fn()}));
vi.mock("../mutations", () => mutations);

const pdf = (name: string) => new File(["x"], name, {type: "application/pdf"});

beforeEach(() => {
  mutations.uploadFile.mockReset().mockImplementation(async (_uid, _parent, _file, onProgress) => {
    onProgress?.(0.5);
    onProgress?.(1);
    return "id";
  });
});

describe("UploadPanel", () => {
  it("envia os arquivos escolhidos, mostra concluído e avisa a tela", async () => {
    const onUploaded = vi.fn();
    render(<UploadPanel uid="t1" parentId="f1" onUploaded={onUploaded} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf"), pdf("b.pdf")]}});
    await waitFor(() => expect(screen.getAllByText("Enviado")).toHaveLength(2));
    expect(mutations.uploadFile).toHaveBeenCalledTimes(2);
    expect(mutations.uploadFile.mock.calls[0].slice(0, 3)).toEqual(["t1", "f1", expect.any(File)]);
    expect(onUploaded).toHaveBeenCalled();
  });

  it("arrastar e soltar também envia", async () => {
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.drop(screen.getByTestId("drop-zone"), {dataTransfer: {files: [pdf("c.pdf")]}});
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("falha de um arquivo mostra o motivo e não impede os outros", async () => {
    mutations.uploadFile.mockImplementationOnce(async () => {
      throw new UploadError("validate", "O arquivo passa de 100 MB.");
    });
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("grande.pdf"), pdf("ok.pdf")]}});
    expect(await screen.findByText("O arquivo passa de 100 MB.")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("erro inesperado mostra mensagem genérica", async () => {
    mutations.uploadFile.mockRejectedValueOnce(new Error("boom"));
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf")]}});
    expect(await screen.findByText("Não foi possível enviar o arquivo. Tente novamente.")).toBeInTheDocument();
  });
});
