import {collection, getDocs} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {TAG_KINDS, type Tag, type TagKind} from "./tags";

function isKind(value: unknown): value is TagKind {
  return TAG_KINDS.includes(value as TagKind);
}

// Lê teaching_tags inteira (poucas dezenas de documentos), ordenada por tipo e
// ordem. Documentos malformados são ignorados.
export async function loadTags(): Promise<Tag[]> {
  const snapshot = await getDocs(collection(db, "teaching_tags"));
  const tags: Tag[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!isKind(data.kind) || typeof data.name !== "string") continue;
    tags.push({
      id: doc.id,
      kind: data.kind,
      name: data.name,
      order: typeof data.order === "number" ? data.order : 0,
      active: data.active !== false,
    });
  }
  return tags.sort(
    (a, b) =>
      TAG_KINDS.indexOf(a.kind) - TAG_KINDS.indexOf(b.kind) || a.order - b.order
  );
}
