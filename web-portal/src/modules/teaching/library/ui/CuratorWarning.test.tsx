import {render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {needsCurators} from "../curators";
import {CuratorWarning} from "./CuratorWarning";

const repo = vi.hoisted(() => ({countCurators: vi.fn()}));
vi.mock("../repository", () => repo);

beforeEach(() => {
  repo.countCurators.mockReset();
});

describe("needsCurators", () => {
  it("menos de 3 curadores", () => {
    expect(needsCurators(0)).toBe(true);
    expect(needsCurators(2)).toBe(true);
    expect(needsCurators(3)).toBe(false);
  });
});

describe("CuratorWarning", () => {
  it("avisa quando há menos de 3 curadores, com singular e plural", async () => {
    repo.countCurators.mockResolvedValue(1);
    const {unmount} = render(<CuratorWarning />);
    expect(await screen.findByText(/Há apenas 1 curador\. /)).toBeInTheDocument();
    unmount();
    repo.countCurators.mockResolvedValue(2);
    render(<CuratorWarning />);
    expect(await screen.findByText(/Há apenas 2 curadores\. /)).toBeInTheDocument();
  });

  it("não aparece com 3 ou mais, nem quando a contagem falha", async () => {
    repo.countCurators.mockResolvedValue(3);
    const first = render(<CuratorWarning />);
    await Promise.resolve();
    expect(first.container).toBeEmptyDOMElement();
    first.unmount();
    repo.countCurators.mockRejectedValue(new Error("x"));
    const second = render(<CuratorWarning />);
    await Promise.resolve();
    expect(second.container).toBeEmptyDOMElement();
  });
});
