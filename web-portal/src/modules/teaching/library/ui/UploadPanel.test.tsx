import {chooseTag} from "./chooseTag";
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import {UploadError} from "../uploadFlow";
import {UploadPanel} from "./UploadPanel";

const mutations = vi.hoisted(() => ({uploadFile: vi.fn()}));
vi.mock("../mutations", () => mutations);

const tagList: Tag[] = [
  {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
  {id: "assunto-trindade", kind: "subject", name: "Trindade", order: 1, active: true},
  {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
];
vi.mock("../useTags", () => ({
  useTags: () => ({tags: tagList, error: null, byId: new Map(tagList.map((t) => [t.id, t])), active: () => tagList}),
}));

const TAGS = {typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"]};
const pdf = (name: string) => new File(["x"], name, {type: "application/pdf"});
const chooseAllTags = () => {
  for (const name of ["Artigos", "Trindade", "UMP"]) chooseTag(name);
};

beforeEach(() => {
  mutations.uploadFile.mockReset().mockImplementation(async (_uid, _file, options) => {
    options?.onProgress?.(0.5);
    options?.onProgress?.(1);
    return "id";
  });
});

describe("UploadPanel", () => {
  it("com as três tags envia cada arquivo com as mesmas tags, mostra concluído e avisa a tela", async () => {
    const onUploaded = vi.fn();
    render(<UploadPanel uid="t1" onUploaded={onUploaded} />);
    chooseAllTags();
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf"), pdf("b.pdf")]}});
    await waitFor(() => expect(screen.getAllByText("Enviado")).toHaveLength(2));
    expect(mutations.uploadFile).toHaveBeenCalledTimes(2);
    expect(mutations.uploadFile.mock.calls[0]).toEqual(["t1", expect.any(File), {tags: TAGS, onProgress: expect.any(Function)}]);
    expect(mutations.uploadFile.mock.calls[1][2].tags).toEqual(TAGS);
    expect(onUploaded).toHaveBeenCalled();
  });

  it("sem tag de faixa mostra o erro e não envia nada", async () => {
    render(<UploadPanel uid="t1" onUploaded={vi.fn()} />);
    chooseTag("Artigos");
    chooseTag("Trindade");
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf")]}});
    expect(await screen.findByRole("alert")).toHaveTextContent("Escolha pelo menos uma tag de faixa.");
    expect(mutations.uploadFile).not.toHaveBeenCalled();
  });

  it("arrastar e soltar também exige tags e envia", async () => {
    render(<UploadPanel uid="t1" onUploaded={vi.fn()} />);
    fireEvent.drop(screen.getByTestId("drop-zone"), {dataTransfer: {files: [pdf("c.pdf")]}});
    expect(await screen.findByRole("alert")).toHaveTextContent("Escolha pelo menos uma tag de tipo.");
    expect(mutations.uploadFile).not.toHaveBeenCalled();
    chooseAllTags();
    fireEvent.drop(screen.getByTestId("drop-zone"), {dataTransfer: {files: [pdf("c.pdf")]}});
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("falha de um arquivo mostra o motivo e não impede os outros", async () => {
    mutations.uploadFile.mockImplementationOnce(async () => {
      throw new UploadError("validate", "O arquivo passa de 100 MB.");
    });
    render(<UploadPanel uid="t1" onUploaded={vi.fn()} />);
    chooseAllTags();
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("grande.pdf"), pdf("ok.pdf")]}});
    expect(await screen.findByText("O arquivo passa de 100 MB.")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("erro inesperado mostra mensagem genérica", async () => {
    mutations.uploadFile.mockRejectedValueOnce(new Error("boom"));
    render(<UploadPanel uid="t1" onUploaded={vi.fn()} />);
    chooseAllTags();
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf")]}});
    expect(await screen.findByText("Não foi possível enviar o arquivo. Tente novamente.")).toBeInTheDocument();
  });
});
