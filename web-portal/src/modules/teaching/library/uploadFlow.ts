import {contentTypeFor, storagePathFor, validateFile, validateName} from "./files";
import {newFilePayload, resubmitFilePayload} from "./payloads";
import {validateTags, type ItemTags} from "./tags";

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
    file: F;
    tags: ItemTags;
    name?: string;
    onProgress?: (fraction: number) => void;
  }
): Promise<string> {
  const problem = validateFile(input.file);
  if (problem) throw new UploadError("validate", problem);

  // Mesmo limite de validItemName nas regras (1 a 120): recusa em vez de truncar.
  const name = (input.name ?? input.file.name).trim();
  const nameProblem = validateName(name);
  if (nameProblem) throw new UploadError("validate", nameProblem);

  const tagsProblem = validateTags(input.tags);
  if (tagsProblem) throw new UploadError("validate", tagsProblem);

  const id = deps.newId();
  const contentType = contentTypeFor(input.file);

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
          fileName: input.file.name,
          contentType,
          size: input.file.size,
          tags: input.tags,
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

export interface ResubmitDeps<F extends FileLike> {
  newNonce(): string;
  now(): unknown;
  uploadObject(
    path: string,
    file: F,
    contentType: string,
    onProgress: (fraction: number) => void
  ): Promise<void>;
  updateItem(id: string, payload: Record<string, unknown>): Promise<void>;
}

// Reenvio de arquivo devolvido. O caminho leva um sufixo aleatório por tentativa:
// o Storage só aceita criar objetos novos, então repetir o mesmo caminho depois
// de uma falha ao atualizar o item travaria o professor. A regra do item exige
// só o prefixo teaching/materials/{id}/ e um caminho diferente do anterior.
export async function resubmitFileItem<F extends FileLike>(
  deps: ResubmitDeps<F>,
  input: {
    uid: string;
    item: {id: string; version: number};
    file: F;
    tags?: ItemTags;
    onProgress?: (fraction: number) => void;
  }
): Promise<void> {
  const problem = validateFile(input.file);
  if (problem) throw new UploadError("validate", problem);
  const tagsProblem = input.tags ? validateTags(input.tags) : null;
  if (tagsProblem) throw new UploadError("validate", tagsProblem);

  const contentType = contentTypeFor(input.file);
  const storagePath = storagePathFor(
    input.item.id,
    input.item.version + 1,
    `${deps.newNonce()}-${input.file.name}`
  );

  try {
    await deps.uploadObject(storagePath, input.file, contentType, input.onProgress ?? (() => undefined));
  } catch {
    throw new UploadError("upload", "Não foi possível enviar o arquivo. Tente novamente.");
  }

  try {
    await deps.updateItem(
      input.item.id,
      resubmitFilePayload(
        {
          uid: input.uid,
          itemId: input.item.id,
          currentVersion: input.item.version,
          fileName: input.file.name,
          contentType,
          size: input.file.size,
          storagePath,
          tags: input.tags,
        },
        deps.now()
      )
    );
  } catch {
    throw new UploadError(
      "create",
      "O arquivo foi enviado, mas não foi possível reenviar o item. Tente novamente."
    );
  }
}
