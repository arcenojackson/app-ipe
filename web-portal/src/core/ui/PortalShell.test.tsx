import {fireEvent, render, screen} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {AccessClaims} from "@/core/auth/access";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import {electionsModule} from "@/modules/elections/module";
import {teachingModule} from "@/modules/teaching/module";
import {PortalShell} from "./PortalShell";

const nav = vi.hoisted(() => ({path: "/", replace: vi.fn()}));

vi.mock("next/navigation", () => ({
  usePathname: () => nav.path,
  useRouter: () => ({replace: nav.replace}),
}));

const refreshAccess = vi.fn().mockResolvedValue(undefined);
const signOut = vi.fn().mockResolvedValue(undefined);
const user = {displayName: "Ana", email: "ana@ipe.org"} as User;

function renderAt(
  path: string,
  state: AuthState,
  modules = [teachingModule]
) {
  nav.path = path;
  return render(
    <AuthContext.Provider value={{state, refreshAccess, signOut}}>
      <PortalShell modules={modules}>
        <p>conteúdo da página</p>
      </PortalShell>
    </AuthContext.Provider>
  );
}

const signedIn = (claims: AccessClaims): AuthState => ({status: "signedIn", user, claims});
const noRole: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const admin: AccessClaims = {admin: true, teachingRole: null};

beforeEach(() => {
  try {
    localStorage.removeItem("ipe-portal-menu-collapsed");
  } catch {}
  nav.replace.mockClear();
  refreshAccess.mockClear();
});

describe("PortalShell", () => {
  it("mostra carregando enquanto resolve a sessão", () => {
    renderAt("/ensino", {status: "loading"});
    expect(screen.getByText("Carregando…")).toBeInTheDocument();
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("deslogado é enviado para /login", () => {
    renderAt("/ensino", {status: "signedOut"});
    expect(nav.replace).toHaveBeenCalledWith("/login");
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("conta sem papel vê acesso restrito (nunca tela em branco ou erro)", () => {
    renderAt("/ensino", signedIn(noRole));
    expect(screen.getByText(/acesso restrito ao grupo de professores/i)).toBeInTheDocument();
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("'Verificar acesso novamente' renova o token", () => {
    renderAt("/ensino", signedIn(noRole));
    fireEvent.click(screen.getByRole("button", {name: "Verificar acesso novamente"}));
    expect(refreshAccess).toHaveBeenCalledTimes(1);
  });

  it("professor vê o conteúdo em /ensino, mas não em /ensino/admin", () => {
    renderAt("/ensino", signedIn(teacher));
    expect(screen.getByText("conteúdo da página")).toBeInTheDocument();
    cleanupAndRender("/ensino/admin", signedIn(teacher));
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
    expect(screen.getByText(/acesso restrito/i)).toBeInTheDocument();
  });

  it("admin vê o conteúdo em /ensino/admin e o menu completo", () => {
    renderAt("/ensino/admin", signedIn(admin));
    expect(screen.getByText("conteúdo da página")).toBeInTheDocument();
    expect(screen.getByRole("link", {name: "Grupo de professores"})).toBeInTheDocument();
  });

  it("o menu do professor não mostra itens de admin", () => {
    renderAt("/ensino", signedIn(teacher));
    expect(screen.getByRole("link", {name: "Biblioteca"})).toBeInTheDocument();
    expect(screen.queryByRole("link", {name: "Grupo de professores"})).not.toBeInTheDocument();
  });
});

function cleanupAndRender(path: string, state: AuthState) {
  document.body.innerHTML = "";
  renderAt(path, state);
}

describe("PortalShell: menu só no módulo de ensino", () => {
  const both = [teachingModule, electionsModule];

  it("em /eleicoes não mostra o menu nem a marca do Portal de Ensino", () => {
    renderAt("/eleicoes/abc", signedIn(noRole), both);
    expect(screen.getByText("conteúdo da página")).toBeInTheDocument();
    expect(screen.queryByText("Portal de Ensino")).not.toBeInTheDocument();
    expect(screen.queryByRole("navigation", {name: "Principal"})).not.toBeInTheDocument();
  });

  it("em /eleicoes, deslogado continua indo para /login", () => {
    renderAt("/eleicoes/abc", {status: "signedOut"}, both);
    expect(nav.replace).toHaveBeenCalledWith("/login");
  });

  it("em /ensino o menu do Portal de Ensino continua aparecendo", () => {
    renderAt("/ensino", signedIn(teacher), both);
    expect(screen.getAllByText("Portal de Ensino").length).toBeGreaterThan(0);
    expect(screen.getByRole("navigation", {name: "Principal"})).toBeInTheDocument();
  });
});

describe("PortalShell: menu hambúrguer no celular", () => {
  const openMenu = () => fireEvent.click(screen.getByRole("button", {name: "Abrir menu"}));
  const menu = () => document.getElementById("portal-menu")!;

  it("começa fechado e o ☰ abre e expõe aria-expanded", () => {
    renderAt("/ensino", signedIn(teacher));
    const burger = screen.getByRole("button", {name: "Abrir menu"});
    expect(burger).toHaveAttribute("aria-expanded", "false");
    expect(menu()).toHaveClass("invisible");
    fireEvent.click(burger);
    expect(burger).toHaveAttribute("aria-expanded", "true");
    expect(menu()).not.toHaveClass("invisible");
  });

  it("ao abrir, o foco vai para o X; ao fechar, volta para o ☰", () => {
    renderAt("/ensino", signedIn(teacher));
    openMenu();
    const [, x] = screen.getAllByRole("button", {name: "Fechar menu"});
    expect(x).toHaveFocus();
    fireEvent.click(x);
    expect(screen.getByRole("button", {name: "Abrir menu"})).toHaveFocus();
  });

  it("fecha ao tocar fora, no X, com Esc e ao escolher um item", () => {
    renderAt("/ensino", signedIn(teacher));
    const closed = () => expect(menu()).toHaveClass("invisible");

    openMenu();
    fireEvent.click(screen.getAllByRole("button", {name: "Fechar menu"})[0]);
    closed();

    openMenu();
    fireEvent.click(screen.getAllByRole("button", {name: "Fechar menu"})[1]);
    closed();

    openMenu();
    fireEvent.keyDown(document, {key: "Escape"});
    closed();

    openMenu();
    fireEvent.click(screen.getByRole("link", {name: "Biblioteca"}));
    closed();
  });

  it("em /eleicoes não há botão de menu", () => {
    renderAt("/eleicoes/abc", signedIn(noRole), [teachingModule, electionsModule]);
    expect(screen.queryByRole("button", {name: "Abrir menu"})).not.toBeInTheDocument();
  });
});

describe("PortalShell: menu recolhível no desktop", () => {
  const menu = () => document.getElementById("portal-menu")!;
  const toggle = () => screen.getByRole("button", {name: /^(Recolher|Expandir) menu$/});

  it("começa expandido; o botão recolhe e expande com aria-expanded", () => {
    renderAt("/ensino", signedIn(teacher));
    expect(toggle()).toHaveAttribute("aria-label", "Recolher menu");
    expect(toggle()).toHaveAttribute("aria-expanded", "true");
    expect(menu()).toHaveClass("md:w-64");
    fireEvent.click(toggle());
    expect(toggle()).toHaveAttribute("aria-label", "Expandir menu");
    expect(toggle()).toHaveAttribute("aria-expanded", "false");
    expect(menu()).toHaveClass("md:w-16");
    fireEvent.click(toggle());
    expect(menu()).toHaveClass("md:w-64");
  });

  it("recolhido, os links mantêm nome acessível e title", () => {
    renderAt("/ensino", signedIn(teacher));
    fireEvent.click(toggle());
    expect(screen.getByRole("link", {name: "Biblioteca"})).toHaveAttribute("title", "Biblioteca");
    expect(screen.getByRole("button", {name: "Sair"})).toBeInTheDocument();
  });

  it("lembra a preferência no navegador", () => {
    const first = renderAt("/ensino", signedIn(teacher));
    fireEvent.click(toggle());
    first.unmount();
    renderAt("/ensino", signedIn(teacher));
    expect(menu()).toHaveClass("md:w-16");
  });

  it("funciona sem localStorage", () => {
    const spy = vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("bloqueado");
    });
    const set = vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("bloqueado");
    });
    renderAt("/ensino", signedIn(teacher));
    fireEvent.click(toggle());
    expect(menu()).toHaveClass("md:w-16");
    spy.mockRestore();
    set.mockRestore();
  });
});
