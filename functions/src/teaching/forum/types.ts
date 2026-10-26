export interface TopicData {
  authorUid: string;
  title: string;
  deleted: boolean;
}

export interface CommentData {
  authorUid: string;
  authorName: string;
  parentId: string | null;
  body: string;
  deleted: boolean;
  createdAt: Date;
}

export interface TopicStats {
  commentCount: number;
  lastActivityAt?: Date;
}

export interface ForumDb {
  getTopic(topicId: string): Promise<TopicData | null>;
  getComment(topicId: string, commentId: string): Promise<CommentData | null>;
  countActiveComments(topicId: string): Promise<number>;
  sumVotes(topicId: string, commentId: string): Promise<number>;
  setTopicStats(topicId: string, stats: TopicStats): Promise<void>;
  setCommentScore(
    topicId: string,
    commentId: string,
    score: number
  ): Promise<void>;
}

export interface ForumNotification {
  id: string;
  toUid: string;
  title: string;
  body: string;
  topicId: string;
  commentId: string;
}

export interface ForumNotifier {
  notify(notification: ForumNotification): Promise<void>;
}

export interface ForumDeps {
  db: ForumDb;
  notifier: ForumNotifier;
}
