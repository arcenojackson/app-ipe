import {fireEvent, render, screen} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {AccessClaims} from "@/core/auth/access";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
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

function renderAt(path: string, state: AuthState) {
  nav.path = path;
  return render(
    <AuthContext.Provider value={{state, refreshAccess, signOut}}>
      <PortalShell modules={[teachingModule]}>
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
    expect(screen.getByRole("link", {name: "Início"})).toBeInTheDocument();
    expect(screen.queryByRole("link", {name: "Grupo de professores"})).not.toBeInTheDocument();
  });
});

function cleanupAndRender(path: string, state: AuthState) {
  document.body.innerHTML = "";
  renderAt(path, state);
}
