import {getBytes, getDownloadURL, ref} from "firebase/storage";
import {storage} from "@/core/firebase/client";

// A leitura é autorizada pelas regras do Storage (consulta o item no Firestore).
export function downloadUrl(storagePath: string): Promise<string> {
  return getDownloadURL(ref(storage, storagePath));
}

// Bytes do arquivo pelo SDK autenticado (sem URL pública). O navegador faz a
// leitura com CORS: o bucket precisa liberar a origem do portal (storage-cors.json).
export function fileBytes(storagePath: string): Promise<ArrayBuffer> {
  return getBytes(ref(storage, storagePath));
}
