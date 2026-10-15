import {collection, doc, getDocs, updateDoc} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toMemberRow, type MemberRow, type TeachingRoleValue} from "./memberRows";

export async function listMembers(): Promise<MemberRow[]> {
  const snapshot = await getDocs(collection(db, "users"));
  return snapshot.docs
    .map((d) => toMemberRow(d.id, d.data()))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
}

/** Só administradores conseguem gravar (regras do Firestore). */
export async function setTeachingRole(uid: string, role: TeachingRoleValue): Promise<void> {
  await updateDoc(doc(db, "users", uid), {teaching_role: role});
}
