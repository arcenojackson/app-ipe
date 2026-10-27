import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import {UploadError} from "../uploadFlow";
import {chooseTag} from "./chooseTag";
import {UploadDrawer} from "./UploadDrawer";

const mutations = vi.hoisted(() => ({uploadFile: vi.fn(), createLink: vi.fn()}));
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
const pick = (...files: File[]) =>
  fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files}});
const send = () => screen.getByRole("button", {name: /^Envia/});
const renderDrawer = (props: Partial<Parameters<typeof UploadDrawer>[0]> = {}) =>
  render(<UploadDrawer uid="t1" onClose={vi.fn()} {...props} />);

beforeEach(() => {
  vi.restoreAllMocks();
  mutations.uploadFile.mockReset().mockImplementation(async (_uid, _file, options) => {
    options?.onProgress?.(1);
    return "id";
  });
  mutations.createLink.mockReset().mockResolvedValue("id");
});

describe("UploadDrawer", () => {
  it("nada é enviado ao escolher arquivo ou tags; o botão diz o que falta", () => {
    renderDrawer();
    expect(send()).toBeDisabled();
    expect(screen.getByText(/Falta: arquivo ou link, tag de tipo, tag de assunto, tag de faixa etária/)).toBeInTheDocument();
    pick(pdf("a.pdf"));
    chooseTag("Artigos");
    chooseTag("Trindade");
    expect(screen.getByText("Falta: tag de faixa etária")).toBeInTheDocument();
    expect(send()).toBeDisabled();
    expect(mutations.uploadFile).not.toHaveBeenCalled();
  });

  it("ordem livre: tags antes do arquivo; só envia ao clicar em Enviar", async () => {
    const onSubmitted = vi.fn();
    renderDrawer({onSubmitted});
    chooseAllTags();
    expect(screen.getByText("Falta: arquivo ou link")).toBeInTheDocument();
    pick(pdf("a.pdf"), pdf("b.pdf"));
    expect(mutations.uploadFile).not.toHaveBeenCalled();
    fireEvent.click(send());
    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent("Enviado!"));
    expect(mutations.uploadFile).toHaveBeenCalledTimes(2);
    expect(mutations.uploadFile.mock.calls[0]).toEqual(["t1", expect.any(File), {tags: TAGS, name: undefined, onProgress: expect.any(Function)}]);
    expect(onSubmitted).toHaveBeenCalledTimes(2);
    expect(screen.getByText(/Falta: arquivo ou link/)).toBeInTheDocument();
  });

  it("arrastar e soltar só adiciona o cartão, sem enviar; dá para remover", () => {
    renderDrawer();
    fireEvent.drop(screen.getByTestId("drop-zone"), {dataTransfer: {files: [pdf("c.pdf")]}});
    expect(screen.getByText("c.pdf")).toBeInTheDocument();
    expect(mutations.uploadFile).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", {name: "Remover c.pdf"}));
    expect(screen.queryByText("c.pdf")).not.toBeInTheDocument();
  });

  it("um arquivo com nome digitado usa esse nome", async () => {
    renderDrawer();
    chooseAllTags();
    pick(pdf("a.pdf"));
    fireEvent.change(screen.getByLabelText(/^Nome/), {target: {value: "Aula 1"}});
    fireEvent.click(send());
    await waitFor(() => expect(mutations.uploadFile).toHaveBeenCalled());
    expect(mutations.uploadFile.mock.calls[0][2].name).toBe("Aula 1");
  });

  it("link: exige nome e endereço válido e cria o link com as tags", async () => {
    renderDrawer();
    chooseAllTags();
    fireEvent.click(screen.getByRole("button", {name: "Adicionar link"}));
    expect(screen.getByText(/Falta: nome do link, endereço do link/)).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText(/^Nome/), {target: {value: "Site"}});
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://ipe.org"}});
    expect(mutations.createLink).not.toHaveBeenCalled();
    fireEvent.click(send());
    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent("Enviado!"));
    expect(mutations.createLink).toHaveBeenCalledWith("t1", {name: "Site", url: "https://ipe.org", description: "", tags: TAGS});
  });

  it("durante o envio mostra 'Enviando…' e ignora cliques duplos", async () => {
    let finish!: () => void;
    mutations.uploadFile.mockImplementation(() => new Promise<string>((resolve) => { finish = () => resolve("id"); }));
    renderDrawer();
    chooseAllTags();
    pick(pdf("a.pdf"));
    fireEvent.click(send());
    fireEvent.click(send());
    expect(screen.getByRole("button", {name: "Enviando…"})).toBeDisabled();
    expect(mutations.uploadFile).toHaveBeenCalledTimes(1);
    finish();
    await waitFor(() => expect(screen.getByRole("status")).toBeInTheDocument());
  });

  it("falha mantém o que foi preenchido e tentar de novo reenvia só o que falhou", async () => {
    mutations.uploadFile.mockImplementationOnce(async () => {
      throw new UploadError("validate", "O arquivo passa de 100 MB.");
    });
    renderDrawer();
    chooseAllTags();
    pick(pdf("grande.pdf"), pdf("ok.pdf"));
    fireEvent.click(send());
    expect(await screen.findByText("O arquivo passa de 100 MB.")).toBeInTheDocument();
    expect(screen.getByRole("alert")).toHaveTextContent("O que você preencheu foi mantido");
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
    fireEvent.click(send());
    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent("Enviado!"));
    expect(mutations.uploadFile).toHaveBeenCalledTimes(3);
  });

  it("erro inesperado mostra mensagem genérica", async () => {
    mutations.uploadFile.mockRejectedValueOnce(new Error("boom"));
    renderDrawer();
    chooseAllTags();
    pick(pdf("a.pdf"));
    fireEvent.click(send());
    expect(await screen.findByText("Não foi possível enviar o arquivo. Tente novamente.")).toBeInTheDocument();
  });

  it("fechar com dados pede confirmação; sem dados fecha direto", () => {
    const onClose = vi.fn();
    const confirm = vi.spyOn(window, "confirm").mockReturnValue(false);
    renderDrawer({onClose});
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalledTimes(1);
    confirm.mockClear();

    onClose.mockClear();
    pick(pdf("a.pdf"));
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(confirm).toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
    confirm.mockReturnValue(true);
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
