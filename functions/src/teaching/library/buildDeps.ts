import * as admin from "firebase-admin";
import {createAdminLibraryDb} from "./adapterDb";
import {
  createFirestoreAudit,
  createFirestoreNotifier,
} from "./adapterNotifier";
import {createAuthRoles} from "./adapterRoles";
import {createBucketStorage} from "./adapterStorage";
import {DEFAULT_BUCKET} from "./constants";
import type {LibraryDeps} from "./types";

// Criado dentro do gatilho: o admin.initializeApp() do index.ts já rodou.
export function buildDeps(): LibraryDeps {
  const firestore = admin.firestore();
  return {
    db: createAdminLibraryDb(firestore),
    storage: createBucketStorage(admin.storage().bucket(DEFAULT_BUCKET)),
    roles: createAuthRoles(admin.auth()),
    notifier: createFirestoreNotifier(firestore, admin.messaging()),
    audit: createFirestoreAudit(firestore),
  };
}
