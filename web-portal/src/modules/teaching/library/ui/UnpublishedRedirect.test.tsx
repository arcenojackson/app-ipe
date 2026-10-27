import {render} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {UnpublishedRedirect} from "./LibraryPage";

const repo = vi.hoisted(() => ({subscribeItem: vi.fn(), loadUserNames: vi.fn()}));
vi.mock("../repository", () => repo);
vi.mock("../useLibraryPage", () => ({useLibraryPage: vi.fn()}));
vi.mock("../useTags", () => ({useTags: vi.fn()}));
vi.mock("../notifications", () => ({subscribeNotifications: vi.fn()}));
vi.mock("./ItemModal", () => ({ItemModal: () => null}));
vi.mock("next/navigation", () => ({useRouter: () => ({}), useSearchParams: () => new URLSearchParams()}));

const emit = (status: string | null) =>
  repo.subscribeItem.mockImplementation((_id, onData) => {
    onData(status ? {id: "i1", status} : null);
    return vi.fn();
  });

beforeEach(() => {
  repo.subscribeItem.mockReset();
});

describe("UnpublishedRedirect (link de push para item não publicado)", () => {
  it("item em revisão manda para a Fila", () => {
    emit("in_review");
    const onRedirect = vi.fn();
    render(<UnpublishedRedirect itemId="i1" onRedirect={onRedirect} />);
    expect(onRedirect).toHaveBeenCalledWith("i1");
  });

  it("publicado, inexistente ou sem item não redireciona", () => {
    const onRedirect = vi.fn();
    emit("published");
    render(<UnpublishedRedirect itemId="i1" onRedirect={onRedirect} />);
    emit(null);
    render(<UnpublishedRedirect itemId="i1" onRedirect={onRedirect} />);
    render(<UnpublishedRedirect itemId={null} onRedirect={onRedirect} />);
    expect(onRedirect).not.toHaveBeenCalled();
  });
});
