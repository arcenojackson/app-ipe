import {describe, expect, it, vi} from "vitest";
import {createBucketStorage} from "../../src/teaching/library/adapterStorage";

type FakeFile = {name: string; delete: ReturnType<typeof vi.fn>};
const file = (name: string): FakeFile => ({name, delete: vi.fn(async () => undefined)});

function fakeBucket(files: FakeFile[]) {
  return {getFiles: vi.fn(async () => [files])};
}

describe("createBucketStorage", () => {
  it("lista pelo prefixo do item e apaga tudo", async () => {
    const files = [file("teaching/materials/i1/v1-a.pdf"), file("teaching/materials/i1/v2-b.pdf")];
    const bucket = fakeBucket(files);
    await createBucketStorage(bucket as never).deleteItemFiles("i1");
    expect(bucket.getFiles).toHaveBeenCalledWith({prefix: "teaching/materials/i1/"});
    expect(files[0].delete).toHaveBeenCalledWith({ignoreNotFound: true});
    expect(files[1].delete).toHaveBeenCalledWith({ignoreNotFound: true});
  });

  it("mantém o objeto atual (keepPath) e apaga os outros", async () => {
    const files = [file("teaching/materials/i1/v1-a.pdf"), file("teaching/materials/i1/v2-b.pdf")];
    await createBucketStorage(fakeBucket(files) as never).deleteItemFiles("i1", "teaching/materials/i1/v2-b.pdf");
    expect(files[0].delete).toHaveBeenCalled();
    expect(files[1].delete).not.toHaveBeenCalled();
  });

  it("item sem objetos não falha", async () => {
    await expect(createBucketStorage(fakeBucket([]) as never).deleteItemFiles("i1")).resolves.toBeUndefined();
  });
});
