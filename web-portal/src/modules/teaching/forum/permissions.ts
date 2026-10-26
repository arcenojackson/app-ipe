import type {Viewer} from "../library/types";
import {LIMITS} from "./types";
import type {Comment, Topic} from "./types";

// Espelha as regras do Firestore; as regras continuam sendo a barreira real.
const isModerator = (viewer: Viewer): boolean => viewer.isCurator || viewer.isAdmin;

export interface TopicPermissions {
  canEdit: boolean;
  canDelete: boolean;
  canPin: boolean;
  canLock: boolean;
  canComment: boolean;
  visibleBody: boolean;
}

export function topicPermissions(topic: Topic, viewer: Viewer): TopicPermissions {
  const author = topic.authorUid === viewer.uid;
  const moderator = isModerator(viewer);
  return {
    canEdit: author && !topic.deleted,
    canDelete: !topic.deleted && (author || moderator),
    canPin: moderator && !topic.deleted,
    canLock: moderator && !topic.deleted,
    canComment: !topic.locked && !topic.deleted,
    visibleBody: !topic.deleted || author || moderator,
  };
}

export interface CommentPermissions {
  canReply: boolean;
  canVote: boolean;
  canEdit: boolean;
  canDelete: boolean;
}

export function commentPermissions(
  comment: Comment,
  topic: Topic,
  viewer: Viewer
): CommentPermissions {
  const author = comment.authorUid === viewer.uid;
  const open = !topic.locked && !topic.deleted && !comment.deleted;
  return {
    canReply: open && comment.depth < LIMITS.maxDepth,
    canVote: open && !author,
    canEdit: author && !comment.deleted,
    canDelete: !comment.deleted && (author || isModerator(viewer)),
  };
}
