import {getDownloadURL, ref} from "firebase/storage";
import {storage} from "@/core/firebase/client";

// A leitura é autorizada pelas regras do Storage (consulta o item no Firestore).
export function downloadUrl(storagePath: string): Promise<string> {
  return getDownloadURL(ref(storage, storagePath));
}
