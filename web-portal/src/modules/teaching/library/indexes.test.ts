import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, expect, it} from "vitest";

const root = resolve(process.cwd(), "..");
const read = (file: string) => JSON.parse(readFileSync(resolve(root, file), "utf8"));

interface IndexDef {
  collectionGroup: string;
  queryScope: string;
  fields: Array<{fieldPath: string; order?: string; arrayConfig?: string}>;
}

describe("firestore.indexes.json", () => {
  const all: IndexDef[] = read("firestore.indexes.json").indexes;
  const indexes = all.filter((i) => i.collectionGroup === "teaching_items");

  it("preserva os índices que já existiam em produção (o deploy não pode removê-los)", () => {
    const others = all.filter((i) => i.collectionGroup !== "teaching_items").map((i) => i.collectionGroup).sort();
    expect(others).toEqual(["forum_topics", "forum_topics", "forum_topics", "messages","music_evaluation_forms", "music_evaluation_forms", "responses", "responses"]);
  });

  it("tem o índice base e um por filtro de servidor, sempre com status e publishedAt desc", () => {
    expect(indexes).toHaveLength(5);
    expect(indexes.every((i) => i.collectionGroup === "teaching_items" && i.queryScope === "COLLECTION")).toBe(true);
    for (const index of indexes) {
      expect(index.fields[0]).toEqual({fieldPath: "status", order: "ASCENDING"});
      expect(index.fields.at(-1)).toEqual({fieldPath: "publishedAt", order: "DESCENDING"});
    }
    const arrays = indexes
      .map((i) => i.fields.find((f) => f.arrayConfig))
      .filter(Boolean)
      .map((f) => [f?.fieldPath, f?.arrayConfig]);
    expect(arrays.sort()).toEqual(
      [["ageTags", "CONTAINS"], ["searchTokens", "CONTAINS"], ["subjectTags", "CONTAINS"], ["typeTags", "CONTAINS"]]
    );
  });

  it("firebase.json aponta para o arquivo de índices", () => {
    expect(read("firebase.json").firestore.indexes).toBe("firestore.indexes.json");
  });
});
