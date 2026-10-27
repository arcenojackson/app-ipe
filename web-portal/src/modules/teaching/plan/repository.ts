import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  updateDoc,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toPlanRow} from "./convert";
import {newPlanRowPayload, planFieldPatch} from "./payloads";
import type {PlanField, PlanRow} from "./types";

const rows = () => collection(db, "teaching_plan");

// Plano ao vivo, na ordem das aulas. O primeiro erro é terminal.
export function subscribePlan(
  onData: (rows: PlanRow[]) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    query(rows(), orderBy("lesson", "asc")),
    (snapshot) =>
      onData(
        snapshot.docs
          .map((d) => toPlanRow(d.id, d.data()))
          .filter((row): row is PlanRow => row !== null)
      ),
    onError
  );
}

export async function savePlanField(
  uid: string,
  id: string,
  field: PlanField,
  value: string
): Promise<void> {
  await updateDoc(doc(rows(), id), planFieldPatch({uid, field, value}, serverTimestamp()));
}

export async function addPlanRow(uid: string, lesson: number, theme: string): Promise<void> {
  await addDoc(rows(), newPlanRowPayload({uid, lesson, theme}, serverTimestamp()));
}

export async function deletePlanRow(id: string): Promise<void> {
  await deleteDoc(doc(rows(), id));
}

// Uma aula pelo id do documento (citações do Fórum); undefined se não existe mais.
export async function loadPlanRow(id: string): Promise<PlanRow | undefined> {
  const snapshot = await getDoc(doc(rows(), id));
  if (!snapshot.exists()) return undefined;
  return toPlanRow(snapshot.id, snapshot.data()) ?? undefined;
}
