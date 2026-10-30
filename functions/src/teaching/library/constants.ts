export const ITEMS_COLLECTION = "teaching_items";
export const VOTES_SUBCOLLECTION = "votes";
export const NOTIFICATIONS_COLLECTION = "teaching_notifications";
export const AUDIT_COLLECTION = "teaching_log";
export const STORAGE_PREFIX = "teaching/materials";

// No emulador (`FUNCTIONS_EMULATOR`) nada aponta para produção: bucket do
// projeto demo e portal em localhost. Veja docs/DESENVOLVIMENTO_LOCAL.md.
const IS_EMULATOR = process.env.FUNCTIONS_EMULATOR === "true";
export const DEFAULT_BUCKET = IS_EMULATOR ?
  "demo-ipe.appspot.com" :
  "app-ipe.firebasestorage.app";
export const PORTAL_URL = IS_EMULATOR ?
  "http://localhost:3000" :
  "https://ipe-ensino.vercel.app";
export const NOTIFICATION_PREFERENCE = "teaching_review";

export const REQUIRED_APPROVALS = 2;
export const REQUIRED_REJECTIONS = 2;
export const REQUIRED_DELETE_APPROVALS = 2;
export const MAX_DEPTH = 8;
export const BATCH_SIZE = 25;
