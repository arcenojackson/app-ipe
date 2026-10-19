import {contentTypeFor, storagePathFor, validateFile} from "./files";
import {newFilePayload} from "./payloads";

export interface FileLike {
  name: string;
  size: number;
  type: string;
}

export interface UploadDeps<F extends FileLike> {
  newId(): string;
  now(): unknown;
  uploadObject(
    path: string,
    file: F,
    contentType: string,
    onProgress: (fraction: number) => void
  ): Promise<void>;
  createItem(id: string, payload: Record<string, unknown>): Promise<void>;
}

export class UploadError extends Error {
  constructor(
    public readonly stage: "validate" | "upload" | "create",
    message: string
  ) {
    super(message);
  }
}

// Ordem: validar → enviar o arquivo → criar o documento. Se o documento não
// for criado o objeto fica órfão e ilegível (as regras exigem o item).
export async function uploadFileItem<F extends FileLike>(
  deps: UploadDeps<F>,
  input: {
    uid: string;
    parentId: string | null;
    file: F;
    name?: string;
    onProgress?: (fraction: number) => void;
  }
): Promise<string> {
  const problem = validateFile(input.file);
  if (problem) throw new UploadError("validate", problem);

  const id = deps.newId();
  const contentType = contentTypeFor(input.file);
  const name = (input.name ?? input.file.name).trim().slice(0, 120);

  try {
    await deps.uploadObject(
      storagePathFor(id, 1, input.file.name),
      input.file,
      contentType,
      input.onProgress ?? (() => undefined)
    );
  } catch {
    throw new UploadError(
      "upload",
      "Não foi possível enviar o arquivo. Tente novamente."
    );
  }

  try {
    await deps.createItem(
      id,
      newFilePayload(
        {
          uid: input.uid,
          itemId: id,
          name,
          parentId: input.parentId,
          fileName: input.file.name,
          contentType,
          size: input.file.size,
        },
        deps.now()
      )
    );
  } catch {
    throw new UploadError(
      "create",
      "O arquivo foi enviado, mas não foi possível registrar o item. Tente novamente."
    );
  }
  return id;
}
