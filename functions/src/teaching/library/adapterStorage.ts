import type * as admin from "firebase-admin";
import {BATCH_SIZE, STORAGE_PREFIX} from "./constants";
import type {LibraryStorage} from "./types";
import {chunks} from "./util";

export type Bucket = ReturnType<admin.storage.Storage["bucket"]>;

export function createBucketStorage(bucket: Bucket): LibraryStorage {
  return {
    async deleteItemFiles(itemId, keepPath) {
      const [files] = await bucket.getFiles({
        prefix: `${STORAGE_PREFIX}/${itemId}/`,
      });
      const doomed = files.filter((file) => file.name !== keepPath);
      for (const part of chunks(doomed, BATCH_SIZE)) {
        await Promise.all(
          part.map((file) => file.delete({ignoreNotFound: true}))
        );
      }
    },
  };
}
