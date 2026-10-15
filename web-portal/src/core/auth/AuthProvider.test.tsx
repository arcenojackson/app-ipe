import {act, fireEvent, render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthProvider} from "./AuthProvider";
import {useAuth} from "./AuthContext";

type Listener = (user: unknown) => void | Promise<void>;

const h = vi.hoisted(() => ({
  listener: null as null | ((user: unknown) => void | Promise<void>),
  authMock: {currentUser: null as unknown},
}));

vi.mock("firebase/auth", () => ({
  onAuthStateChanged: (_auth: unknown, cb: Listener) => {
    h.listener = cb;
    return () => {
      h.listener = null;
    };
  },
  signOut: vi.fn(async () => {}),
}));

vi.mock("@/core/firebase/client", () => ({auth: h.authMock}));

function deferred<T>() {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>((r) => {
    resolve = r;
  });
  return {promise, resolve};
}

function makeUser(uid: string, tokenPromise: Promise<{claims: Record<string, unknown>}>) {
  return {uid, getIdTokenResult: vi.fn(() => tokenPromise)};
}

function Consumer() {
  const {state, refreshAccess} = useAuth();
  return (
    <div>
      <span data-testid="status">{state.status}</span>
      <span data-testid="role">
        {state.status === "signedIn" ? String(state.claims.teachingRole) : "-"}
      </span>
      <button onClick={() => void refreshAccess()}>refresh</button>
    </div>
  );
}

function renderProvider() {
  return render(
    <AuthProvider>
      <Consumer />
    </AuthProvider>
  );
}

const status = () => screen.getByTestId("status").textContent;

describe("AuthProvider", () => {
  beforeEach(() => {
    h.listener = null;
    h.authMock.currentUser = null;
  });

  it("logout durante a busca do token não ressuscita a sessão", async () => {
    renderProvider();
    const token = deferred<{claims: Record<string, unknown>}>();
    const user = makeUser("u1", token.promise);
    h.authMock.currentUser = user;

    let pending: void | Promise<void>;
    act(() => {
      pending = h.listener!(user);
    });
    h.authMock.currentUser = null;
    await act(async () => {
      await h.listener!(null);
    });
    expect(status()).toBe("signedOut");

    await act(async () => {
      token.resolve({claims: {teaching_role: "teacher"}});
      await pending;
    });
    expect(status()).toBe("signedOut");
  });

  it("caminho normal: lê e interpreta as claims", async () => {
    renderProvider();
    const user = makeUser("u1", Promise.resolve({claims: {teaching_role: "teacher"}}));
    h.authMock.currentUser = user;
    await act(async () => {
      await h.listener!(user);
    });
    expect(status()).toBe("signedIn");
    expect(screen.getByTestId("role").textContent).toBe("teacher");
  });

  it("refreshAccess após logout não define signedIn", async () => {
    renderProvider();
    await act(async () => {
      await h.listener!(null);
    });
    h.authMock.currentUser = null;
    await act(async () => {
      fireEvent.click(screen.getByText("refresh"));
    });
    expect(status()).toBe("signedOut");
  });

  it("refreshAccess em andamento não ressuscita sessão encerrada", async () => {
    renderProvider();
    const first = makeUser("u1", Promise.resolve({claims: {}}));
    h.authMock.currentUser = first;
    await act(async () => {
      await h.listener!(first);
    });
    expect(status()).toBe("signedIn");

    const token = deferred<{claims: Record<string, unknown>}>();
    first.getIdTokenResult.mockReturnValue(token.promise);
    act(() => {
      fireEvent.click(screen.getByText("refresh"));
    });
    h.authMock.currentUser = null;
    await act(async () => {
      await h.listener!(null);
    });
    await act(async () => {
      token.resolve({claims: {teaching_role: "curator"}});
    });
    expect(status()).toBe("signedOut");
  });
});
