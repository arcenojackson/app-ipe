export type ItemType = "folder" | "file" | "link";
export type ItemStatus = "active" | "in_review" | "returned" | "published";
export type VoteAction =
  | "approve"
  | "reject"
  | "return"
  | "delete_approve"
  | "delete_refuse";

export interface DeleteRequest {
  id: string;
  requestedBy: string;
  requestedAt: number;
  reason?: string;
}

// Visão de domínio de teaching_items/{id}; tempos em milissegundos.
export interface ItemDoc {
  id: string;
  type: ItemType;
  name: string;
  parentId: string | null;
  authorId: string;
  status: ItemStatus;
  version: number;
  updatedBy?: string;
  storagePath?: string;
  typeTags?: string[];
  subjectTags?: string[];
  ageTags?: string[];
  deleteRequest?: DeleteRequest | null;
  returnComment?: string | null;
  returnedBy?: string | null;
  // Marcador só das Functions: remoção decidida e ainda em andamento.
  deleting?: "reject" | "execute" | null;
}

// Visão de domínio de teaching_items/{id}/votes/{voteId}.
export interface VoteDoc {
  id: string;
  voterId: string;
  action: VoteAction;
  version?: number;
  requestId?: string;
  comment?: string;
  createdAt: number;
}

// Campos que as Functions podem gravar no item.
export interface ItemPatch {
  status?: ItemStatus;
  // true = grava o horário do servidor (publicação).
  publishedAt?: true;
  // Curadores que aprovaram a versão publicada (só as Functions gravam).
  approvedBy?: string[];
  returnComment?: string | null;
  returnedBy?: string | null;
  parentId?: string | null;
  deleteRequest?: DeleteRequest | null;
  deleteRequested?: boolean;
  deleting?: "reject" | "execute" | null;
}

export interface Tx {
  getItem(id: string): Promise<ItemDoc | undefined>;
  listVotes(itemId: string): Promise<VoteDoc[]>;
  // Escritas são aplicadas ao final da transação.
  updateItem(id: string, patch: ItemPatch): void;
}

export interface LibraryDb {
  transact<T>(fn: (tx: Tx) => Promise<T>): Promise<T>;
  getItem(id: string): Promise<ItemDoc | undefined>;
  listChildren(parentId: string): Promise<ItemDoc[]>;
  updateItem(id: string, patch: ItemPatch): Promise<void>;
  // Apaga o documento e a subcoleção de votos.
  deleteItem(id: string): Promise<void>;
}

export interface LibraryStorage {
  // Apaga os objetos do item, exceto `keepPath` (caminho completo), se dado.
  deleteItemFiles(itemId: string, keepPath?: string): Promise<void>;
}

export interface RolesPort {
  // Dos uids dados, quem hoje tem teaching_role == curator no Auth.
  currentCuratorIds(uids: string[]): Promise<Set<string>>;
  allCuratorIds(): Promise<string[]>;
}

export interface NotificationInput {
  id: string; // determinístico: reprocessar não duplica
  toUid: string;
  type: string;
  itemId: string;
  title: string;
  body: string;
}

export interface Notifier {
  notify(n: NotificationInput): Promise<void>;
}

export interface AuditEntry {
  id: string; // determinístico
  action: string;
  itemId: string;
  itemName: string;
  actors: string[];
}

export interface AuditLog {
  record(entry: AuditEntry): Promise<void>;
}

export interface LibraryDeps {
  db: LibraryDb;
  storage: LibraryStorage;
  roles: RolesPort;
  notifier: Notifier;
  audit: AuditLog;
}
