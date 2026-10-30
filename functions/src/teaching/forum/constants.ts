export const TOPICS_COLLECTION = "forum_topics";
export const COMMENTS_SUBCOLLECTION = "comments";
export const VOTES_SUBCOLLECTION = "votes";
export const NOTIFICATIONS_COLLECTION = "teaching_notifications";

// No emulador o portal roda em localhost (nada aponta para produção).
export const PORTAL_URL = process.env.FUNCTIONS_EMULATOR === "true" ?
  "http://localhost:3000" :
  "https://ipe-ensino.vercel.app";
export const NOTIFICATION_PREFERENCE = "teaching_forum";
export const NOTIFICATION_TYPE = "forum_reply";
export const NOTIFICATION_TITLE = "Nova resposta no Fórum";
export const SNIPPET_LENGTH = 100;
