import type {
  AuditEntry,
  ItemDoc,
  ItemPatch,
  LibraryDb,
  LibraryDeps,
  NotificationInput,
  Tx,
  VoteDoc,
} from "../../src/teaching/library/types";

export function makeItem(
  overrides: Partial<ItemDoc> & {id: string}
): ItemDoc {
  return {
    type: "file",
    name: overrides.id,
    parentId: null,
    authorId: "author",
    status: "in_review",
    version: 1,
    deleteRequest: null,
    ...overrides,
  };
}

export function vote(
  overrides: Partial<VoteDoc> & Pick<VoteDoc, "id" | "voterId" | "action">
): VoteDoc {
  return {createdAt: 1, ...overrides};
}

export class FakeDb implements LibraryDb {
  items = new Map<string, ItemDoc>();
  votes = new Map<string, VoteDoc[]>();

  constructor(items: ItemDoc[] = [], votes: Record<string, VoteDoc[]> = {}) {
    for (const item of items) this.items.set(item.id, item);
    for (const [id, list] of Object.entries(votes)) this.votes.set(id, list);
  }

  async getItem(id: string): Promise<ItemDoc | undefined> {
    const item = this.items.get(id);
    return item ? structuredClone(item) : undefined;
  }

  async listChildren(parentId: string): Promise<ItemDoc[]> {
    return [...this.items.values()]
      .filter((item) => item.parentId === parentId)
      .map((item) => structuredClone(item));
  }

  async updateItem(id: string, patch: ItemPatch): Promise<void> {
    const current = this.items.get(id);
    if (!current) throw new Error(`item ${id} não existe`);
    const clean = Object.fromEntries(
      Object.entries(patch).filter(([, value]) => value !== undefined)
    );
    this.items.set(id, {...current, ...clean});
  }

  async deleteItem(id: string): Promise<void> {
    this.items.delete(id);
    this.votes.delete(id);
  }

  async transact<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    const writes: Array<[string, ItemPatch]> = [];
    const tx: Tx = {
      getItem: (id) => this.getItem(id),
      listVotes: async (id) => structuredClone(this.votes.get(id) ?? []),
      updateItem: (id, patch) => {
        writes.push([id, patch]);
      },
    };
    const result = await fn(tx);
    for (const [id, patch] of writes) await this.updateItem(id, patch);
    return result;
  }
}

export class FakeStorage {
  deleted: Array<{itemId: string; keepPath?: string}> = [];
  failNext = 0;

  async deleteItemFiles(itemId: string, keepPath?: string): Promise<void> {
    if (this.failNext > 0) {
      this.failNext--;
      throw new Error("storage fora do ar");
    }
    this.deleted.push({itemId, keepPath});
  }
}

export class FakeRoles {
  constructor(public curators: string[]) {}

  async currentCuratorIds(uids: string[]): Promise<Set<string>> {
    return new Set(uids.filter((uid) => this.curators.includes(uid)));
  }

  async allCuratorIds(): Promise<string[]> {
    return [...this.curators];
  }
}

export class FakeNotifier {
  sent: NotificationInput[] = [];

  async notify(n: NotificationInput): Promise<void> {
    this.sent.push(n);
  }
}

export class FakeAudit {
  entries: AuditEntry[] = [];

  async record(entry: AuditEntry): Promise<void> {
    this.entries.push(entry);
  }
}

export function makeDeps(options: {
  items?: ItemDoc[];
  votes?: Record<string, VoteDoc[]>;
  curators?: string[];
}) {
  const db = new FakeDb(options.items, options.votes);
  const storage = new FakeStorage();
  const roles = new FakeRoles(options.curators ?? []);
  const notifier = new FakeNotifier();
  const audit = new FakeAudit();
  const deps: LibraryDeps = {db, storage, roles, notifier, audit};
  return {deps, db, storage, roles, notifier, audit};
}
