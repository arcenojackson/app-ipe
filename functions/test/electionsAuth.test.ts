import {describe, expect, it} from "vitest";
import {assertNotAnonymous} from "../src/elections/common";

describe("assertNotAnonymous", () => {
  it("recusa sessão anônima com permission-denied", () => {
    expect(() => assertNotAnonymous(true)).toThrowError(
      expect.objectContaining({code: "permission-denied"})
    );
  });

  it("aceita sessão com conta", () => {
    expect(() => assertNotAnonymous(false)).not.toThrow();
  });
});
