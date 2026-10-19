import type {AccessClaims} from "@/core/auth/access";

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

// Visão de teaching_items/{id}; tempos em milissegundos.
export interface LibraryItem {
  id: string;
  type: ItemType;
  name: string;
  parentId: string | null;
  authorId: string;
  status: ItemStatus;
  version: number;
  updatedBy?: string;
  fileName?: string;
  contentType?: string;
  size?: number;
  storagePath?: string;
  url?: string;
  description?: string;
  returnComment?: string | null;
  returnedBy?: string | null;
  deleteRequest?: DeleteRequest | null;
  deleting?: "reject" | "execute" | null;
  createdAt?: number;
}

// Visão de teaching_items/{id}/votes/{voteId}.
export interface LibraryVote {
  id: string;
  voterId: string;
  action: VoteAction;
  version?: number;
  requestId?: string;
  comment?: string;
  createdAt: number;
}

export interface Viewer {
  uid: string;
  isCurator: boolean;
  isAdmin: boolean;
}

export function viewerFrom(uid: string, claims: AccessClaims): Viewer {
  return {uid, isCurator: claims.teachingRole === "curator", isAdmin: claims.admin};
}
