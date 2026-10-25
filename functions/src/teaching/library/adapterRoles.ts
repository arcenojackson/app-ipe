import type {RolesPort} from "./types";
import {chunks, unique} from "./util";

interface UserLike {
  uid: string;
  customClaims?: Record<string, unknown>;
}

export interface AuthLike {
  getUsers(ids: Array<{uid: string}>): Promise<{users: UserLike[]}>;
  listUsers(
    maxResults?: number,
    pageToken?: string
  ): Promise<{users: UserLike[]; pageToken?: string}>;
}

const isCurator = (user: UserLike) =>
  user.customClaims?.teaching_role === "curator";

// Papel lido do Auth (claims atuais), não do documento do usuário.
export function createAuthRoles(auth: AuthLike): RolesPort {
  return {
    async currentCuratorIds(uids) {
      const found = new Set<string>();
      for (const part of chunks(unique(uids), 100)) {
        const result = await auth.getUsers(part.map((uid) => ({uid})));
        for (const user of result.users) {
          if (isCurator(user)) found.add(user.uid);
        }
      }
      return found;
    },

    async allCuratorIds() {
      const ids: string[] = [];
      let token: string | undefined;
      do {
        const page = await auth.listUsers(1000, token);
        for (const user of page.users) {
          if (isCurator(user)) ids.push(user.uid);
        }
        token = page.pageToken;
      } while (token);
      return ids;
    },
  };
}
