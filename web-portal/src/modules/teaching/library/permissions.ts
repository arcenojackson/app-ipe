import type {LibraryItem, Viewer} from "./types";

export interface ItemPermissions {
  canVote: boolean;
  canRename: boolean;
  canRequestDelete: boolean;
  canCancelDelete: boolean;
  canVoteDelete: boolean;
  canResubmit: boolean;
  canEditTags: boolean;
}

// Espelha as regras do Firestore; as regras continuam sendo a barreira real.
export function itemPermissions(item: LibraryItem, viewer: Viewer): ItemPermissions {
  const none: ItemPermissions = {
    canVote: false,
    canRename: false,
    canRequestDelete: false,
    canCancelDelete: false,
    canVoteDelete: false,
    canResubmit: false,
    canEditTags: false,
  };
  if (item.deleting) return none;

  const request = item.deleteRequest ?? null;
  const decided = item.type !== "folder";
  return {
    canVote:
      viewer.isCurator &&
      decided &&
      item.status === "in_review" &&
      item.authorId !== viewer.uid,
    canRename: viewer.isCurator,
    canRequestDelete:
      viewer.isCurator &&
      request === null &&
      (item.status === "published" || item.status === "active" || item.status === "returned"),
    canCancelDelete: viewer.isCurator && request?.requestedBy === viewer.uid,
    canVoteDelete:
      viewer.isCurator && request !== null && request.requestedBy !== viewer.uid,
    canResubmit:
      decided && item.status === "returned" && item.authorId === viewer.uid,
    canEditTags: viewer.isCurator,
  };
}
