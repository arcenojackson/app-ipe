import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryItem, LibraryVote, Viewer} from "../types";
import {UploadError} from "../uploadFlow";
import {ItemDetail} from "./ItemDetail";

const repo = vi.hoisted(() => ({
  subscribeItem: vi.fn(),
  subscribeVotes: vi.fn(),
  loadUserNames: vi.fn(),
  canReadVotes: vi.fn(),
}));
const mutations = vi.hoisted(() => ({
  castVote: vi.fn(), requestDelete: vi.fn(), cancelDelete: vi.fn(), renameItem: vi.fn(),
  moveItem: vi.fn(), editTags: vi.fn(), resubmitFile: vi.fn(), resubmitLink: vi.fn(),
}));
vi.mock("./PreviewPane", () => ({
  PreviewPane: ({item}: {item: LibraryItem}) => <div data-testid="preview">{`preview de ${item.name}`}</div>,
}));
vi.mock("../useTags", () => {
  const list = [
    {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
    {id: "assunto-trindade", kind: "subject", name: "Trindade", order: 1, active: true},
    {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
  ];
  return {useTags: () => ({tags: list, error: null, byId: new Map(list.map((t) => [t.id, t])), active: () => list})};
});
vi.mock("../repository", () => repo);
vi.mock("../mutations", () => mutations);

const curator1: Viewer = {uid: "c1", isCurator: true, isAdmin: false};
const curator2: Viewer = {uid: "c2", isCurator: true, isAdmin: false};
const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const other: Viewer = {uid: "t2", isCurator: false, isAdmin: false};

const file = (extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "i1", type: "file", name: "Aula 1", parentId: "f1", authorId: "t1", status: "in_review", version: 1,
  fileName: "aula.pdf", contentType: "application/pdf", size: 2048, storagePath: "teaching/materials/i1/v1-aula.pdf", ...extra,
});

let current: LibraryItem | null;
let votes: LibraryVote[];

function setup(viewer: Viewer, item: LibraryItem | null = file(), itemVotes: LibraryVote[] = []) {
  current = item;
  votes = itemVotes;
  repo.canReadVotes.mockImplementation((i: LibraryItem, v: Viewer) => v.isCurator || v.isAdmin || i.authorId === v.uid);
  repo.subscribeItem.mockImplementation((_id, onData) => {
    onData(current);
    return vi.fn();
  });
  // Testes podem pré-configurar estes mocks; os padrões só valem quando não há implementação.
  if (!repo.subscribeVotes.getMockImplementation()) {
    repo.subscribeVotes.mockImplementation((_id, onData) => {
      onData(votes);
      return vi.fn();
    });
  }
  repo.loadUserNames.mockResolvedValue({c1: "Ana Curadora", c2: "Beto Curador", t1: "Felipe"});
  const onClose = vi.fn();
  const onChanged = vi.fn();
  render(<ItemDetail itemId="i1" viewer={viewer} onClose={onClose} onChanged={onChanged} />);
  return {onClose, onChanged};
}

beforeEach(() => {
  for (const fn of [...Object.values(repo), ...Object.values(mutations)]) fn.mockReset();
  for (const fn of Object.values(mutations)) fn.mockResolvedValue(undefined);
});

describe("ItemDetail — votos de publicação", () => {
  it("curador que não é o autor vê Aprovar, Devolver e Rejeitar e aprova", async () => {
    setup(curator2);
    expect(await screen.findByText("Aula 1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Aprovar"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.objectContaining({id: "i1"}), "approve", undefined));
    expect(await screen.findByRole("status")).toHaveTextContent("Voto registrado.");
  });

  it("devolver exige comentário e envia o texto", async () => {
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Devolver"}));
    fireEvent.click(screen.getByRole("button", {name: "Devolver para o autor"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Escreva um comentário.");
    fireEvent.change(screen.getByLabelText("Comentário para o autor"), {target: {value: "Falta a referência"}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver para o autor"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "return", "Falta a referência"));
  });

  it("o comentário é enviado sem espaços nas pontas", async () => {
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Devolver"}));
    fireEvent.change(screen.getByLabelText("Comentário para o autor"), {target: {value: "  Falta a referência \n"}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver para o autor"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "return", "Falta a referência"));
  });

  it("rejeitar exige motivo", async () => {
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Rejeitar"}));
    fireEvent.change(screen.getByLabelText("Motivo da rejeição"), {target: {value: "Fora do escopo"}});
    fireEvent.click(screen.getByRole("button", {name: "Rejeitar envio"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "reject", "Fora do escopo"));
  });

  it("autor curador, professor e admin sem papel não veem botões de voto", async () => {
    setup(curator1, file({authorId: "c1"}));
    await screen.findByText("Aula 1");
    expect(screen.queryByRole("button", {name: "Aprovar"})).not.toBeInTheDocument();
  });

  it("professor autor vê o andamento e nenhuma ação de curador", async () => {
    setup(teacher, file(), [{id: "v1", voterId: "c1", action: "approve", version: 1, createdAt: 1}]);
    await screen.findByText("Aula 1");
    expect(screen.getByText("Aprovações: 1/2")).toBeInTheDocument();
    for (const name of ["Aprovar", "Devolver", "Rejeitar", "Renomear", "Mover", "Pedir exclusão"]) {
      expect(screen.queryByRole("button", {name})).not.toBeInTheDocument();
    }
  });

  it("falha ao votar mostra erro e reabilita", async () => {
    mutations.castVote.mockRejectedValue(new Error("permission-denied"));
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Aprovar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível registrar o voto. Tente novamente.");
    expect(screen.getByRole("button", {name: "Aprovar"})).toBeEnabled();
  });
});

describe("ItemDetail — histórico e visualização", () => {
  it("curador vê os votos com nomes e comentários", async () => {
    setup(curator2, file(), [
      {id: "v1", voterId: "c1", action: "return", version: 1, comment: "Falta a referência", createdAt: 5},
    ]);
    expect(await screen.findByText(/Ana Curadora/)).toBeInTheDocument();
    expect(screen.getByText(/Devolveu/)).toBeInTheDocument();
    expect(screen.getByText("Falta a referência")).toBeInTheDocument();
  });

  it("professor que não é autor não assina os votos", async () => {
    setup(other, file({status: "published"}));
    await screen.findByText("Aula 1");
    expect(repo.subscribeVotes).not.toHaveBeenCalled();
  });

  it("arquivo mostra a visualização (PreviewPane), as tags e o autor", async () => {
    setup(other, file({status: "published", typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"]}));
    expect(await screen.findByTestId("preview")).toHaveTextContent("Aula 1");
    expect(screen.getByText("Artigos")).toBeInTheDocument();
    expect(screen.getByText("Trindade")).toBeInTheDocument();
    expect(screen.getByText("UMP")).toBeInTheDocument();
    expect(await screen.findByText("Enviado por Felipe")).toBeInTheDocument();
  });

  it("link abre em nova aba com rel seguro", async () => {
    setup(other, {id: "i1", type: "link", name: "Livro", parentId: null, authorId: "t1", status: "published", version: 1, url: "https://x.org/livro", description: "Bom livro"});
    const anchor = await screen.findByRole("link", {name: "https://x.org/livro"});
    expect(anchor).toHaveAttribute("target", "_blank");
    expect(anchor).toHaveAttribute("rel", "noopener noreferrer");
    expect(screen.getByText("Bom livro")).toBeInTheDocument();
  });

  it("endereço que não é http(s) aparece como texto, sem link", async () => {
    setup(other, {id: "i1", type: "link", name: "Ruim", parentId: null, authorId: "t1", status: "published", version: 1, url: "javascript:alert(1)"});
    expect(await screen.findByText("javascript:alert(1)")).toBeInTheDocument();
    expect(screen.queryByRole("link", {name: "javascript:alert(1)"})).not.toBeInTheDocument();
  });

  it("item inexistente mostra aviso e fecha", async () => {
    const {onClose} = setup(other, null);
    expect(await screen.findByText("Item não encontrado ou excluído.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalled();
  });

  it("erro de acesso ao item (permission-denied) mostra aviso terminal", async () => {
    const onClose = vi.fn();
    repo.canReadVotes.mockReturnValue(false);
    repo.subscribeItem.mockImplementation((_id, onData, onError) => {
      onError(new Error("permission-denied"));
      onData(file());
      onError(new Error("permission-denied"));
      return vi.fn();
    });
    render(<ItemDetail itemId="i1" viewer={other} onClose={onClose} onChanged={vi.fn()} />);
    expect(await screen.findByText("Item não encontrado ou sem acesso.")).toBeInTheDocument();
    expect(screen.queryByText("Aula 1")).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalled();
  });

  it("item sendo excluído mostra aviso e nenhuma ação", async () => {
    setup(curator2, file({deleting: "reject"}));
    expect(await screen.findByText("Este item está sendo excluído.")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Aprovar"})).not.toBeInTheDocument();
  });
});

describe("ItemDetail — editar tags", () => {
  it("curador edita as tags e salva", async () => {
    const {onChanged} = setup(curator1, file({status: "in_review", typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"]}));
    fireEvent.click(await screen.findByRole("button", {name: "Editar tags"}));
    fireEvent.click(screen.getByRole("checkbox", {name: "UMP"}));
    fireEvent.click(screen.getByRole("checkbox", {name: "UMP"}));
    fireEvent.click(screen.getByRole("button", {name: "Salvar tags"}));
    await waitFor(() => expect(mutations.editTags).toHaveBeenCalledWith("c1", "i1", {
      typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"],
    }));
    await waitFor(() => expect(onChanged).toHaveBeenCalled());
  });

  it("professor autor não vê Editar tags", async () => {
    setup(teacher, file());
    await screen.findByText("Aula 1");
    expect(screen.queryByRole("button", {name: "Editar tags"})).not.toBeInTheDocument();
  });
});

describe("ItemDetail — organizar e excluir", () => {
  it("curador renomeia", async () => {
    const {onChanged} = setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Renomear"}));
    fireEvent.change(screen.getByLabelText("Novo nome"), {target: {value: "Aula 1 revisada"}});
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    await waitFor(() => expect(mutations.renameItem).toHaveBeenCalledWith("c1", "i1", "Aula 1 revisada"));
    await waitFor(() => expect(onChanged).toHaveBeenCalled());
  });

  it("curador pede exclusão com motivo opcional", async () => {
    const {onChanged} = setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Pedir exclusão"}));
    fireEvent.change(screen.getByLabelText("Motivo (opcional)"), {target: {value: "  Obsoleto "}});
    fireEvent.click(screen.getByRole("button", {name: "Enviar pedido"}));
    await waitFor(() => expect(mutations.requestDelete).toHaveBeenCalledWith("c1", "i1", "Obsoleto"));
    await waitFor(() => expect(onChanged).toHaveBeenCalled());
  });

  it("pedido de exclusão sem motivo não envia texto vazio", async () => {
    setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Pedir exclusão"}));
    fireEvent.change(screen.getByLabelText("Motivo (opcional)"), {target: {value: "   "}});
    fireEvent.click(screen.getByRole("button", {name: "Enviar pedido"}));
    await waitFor(() => expect(mutations.requestDelete).toHaveBeenCalledWith("c1", "i1", undefined));
  });

  it("com pedido aberto: outro curador aprova a exclusão", async () => {
    const withRequest = file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1, reason: "Obsoleto"}});
    setup(curator2, withRequest);
    expect(await screen.findByText(/Obsoleto/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Aprovar exclusão"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "delete_approve", undefined));
  });

  it("recusar exclusão exige comentário", async () => {
    setup(curator2, file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}}));
    fireEvent.click(await screen.findByRole("button", {name: "Recusar exclusão"}));
    fireEvent.change(screen.getByLabelText("Motivo da recusa"), {target: {value: "Ainda é usado"}});
    fireEvent.click(screen.getByRole("button", {name: "Recusar pedido"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "delete_refuse", "Ainda é usado"));
  });

  it("quem pediu vê Cancelar pedido e não vota na própria exclusão", async () => {
    setup(curator1, file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}}));
    fireEvent.click(await screen.findByRole("button", {name: "Cancelar pedido de exclusão"}));
    await waitFor(() => expect(mutations.cancelDelete).toHaveBeenCalledWith("c1", "i1"));
    expect(screen.queryByRole("button", {name: "Aprovar exclusão"})).not.toBeInTheDocument();
  });
});

describe("ItemDetail — reenvio", () => {
  it("autor reenvia arquivo devolvido", async () => {
    const {onChanged} = setup(teacher, file({status: "returned", returnComment: "Falta a referência"}));
    expect(await screen.findByText(/Falta a referência/)).toBeInTheDocument();
    const input = screen.getByLabelText("Escolher novo arquivo");
    const novo = new File(["x"], "novo.pdf", {type: "application/pdf"});
    await act(async () => fireEvent.change(input, {target: {files: [novo]}}));
    await waitFor(() => expect(mutations.resubmitFile).toHaveBeenCalledWith("t1", expect.objectContaining({id: "i1"}), novo, expect.any(Function)));
    await waitFor(() => expect(onChanged).toHaveBeenCalled());
  });

  it("autor reenvia link devolvido com nova URL", async () => {
    const {onChanged} = setup(teacher, {id: "i1", type: "link", name: "Livro", parentId: null, authorId: "t1", status: "returned", version: 1, url: "https://velho.org", returnComment: "Link quebrado"});
    fireEvent.click(await screen.findByRole("button", {name: "Reenviar link"}));
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://novo.org"}});
    fireEvent.click(screen.getByRole("button", {name: "Reenviar"}));
    await waitFor(() => expect(mutations.resubmitLink).toHaveBeenCalledWith("t1", expect.objectContaining({id: "i1"}), {url: "https://novo.org", name: "Livro", description: ""}));
    await waitFor(() => expect(onChanged).toHaveBeenCalled());
  });

  it("outro professor não vê o reenvio", async () => {
    setup(other, file({status: "returned"}));
    await screen.findByText("Aula 1");
    expect(screen.queryByLabelText("Escolher novo arquivo")).not.toBeInTheDocument();
  });
});

describe("ItemDetail — reenvio com erro", () => {
  async function pick() {
    const input = await screen.findByLabelText("Escolher novo arquivo");
    const novo = new File(["x"], "novo.exe", {type: "application/x-msdownload"});
    await act(async () => fireEvent.change(input, {target: {files: [novo]}}));
  }

  it("arquivo inválido mostra a mensagem do UploadError", async () => {
    mutations.resubmitFile.mockRejectedValue(new UploadError("validate", "Tipo de arquivo não permitido. Use PDF, Office ou imagem."));
    setup(teacher, file({status: "returned"}));
    await pick();
    expect(await screen.findByRole("alert")).toHaveTextContent("Tipo de arquivo não permitido. Use PDF, Office ou imagem.");
  });

  it("outro erro mostra a mensagem genérica", async () => {
    mutations.resubmitFile.mockRejectedValue(new Error("network"));
    setup(teacher, file({status: "returned"}));
    await pick();
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível reenviar o arquivo. Tente novamente.");
  });
});

describe("ItemDetail — acabamentos", () => {
  it("clique duplo em Aprovar vota uma vez só", async () => {
    mutations.castVote.mockReturnValue(new Promise(() => {}));
    setup(curator2);
    const button = await screen.findByRole("button", {name: "Aprovar"});
    fireEvent.click(button);
    fireEvent.click(button);
    expect(mutations.castVote).toHaveBeenCalledTimes(1);
    expect(button).toBeDisabled();
  });

  it("não mostra o contador antes do primeiro retorno dos votos", async () => {
    repo.subscribeVotes.mockImplementation(() => vi.fn());
    setup(teacher);
    await screen.findByText("Aula 1");
    expect(screen.queryByText(/Aprovações:/)).not.toBeInTheDocument();
    expect(screen.getByText("Em revisão")).toBeInTheDocument();
  });

  it("mostra o voto do curador atual nesta versão", async () => {
    setup(curator2, file(), [
      {id: "v1", voterId: "c2", action: "approve", version: 1, createdAt: 1},
      {id: "v2", voterId: "c2", action: "return", version: 1, comment: "x", createdAt: 2},
      {id: "v3", voterId: "c1", action: "approve", version: 1, createdAt: 3},
    ]);
    expect(await screen.findByText("Seu voto: Devolveu")).toBeInTheDocument();
  });

  it("não mostra Seu voto quando só há votos de versões antigas", async () => {
    setup(curator2, file({version: 2}), [{id: "v1", voterId: "c2", action: "approve", version: 1, createdAt: 1}]);
    await screen.findByText("Aula 1");
    expect(screen.queryByText(/Seu voto/)).not.toBeInTheDocument();
  });

  it("erro ao ler os votos mostra aviso", async () => {
    repo.subscribeVotes.mockImplementation((_id, _onData, onError) => {
      onError(new Error("x"));
      return vi.fn();
    });
    setup(curator2);
    expect(await screen.findByText("Não foi possível carregar o histórico de revisão.")).toBeInTheDocument();
  });
});
