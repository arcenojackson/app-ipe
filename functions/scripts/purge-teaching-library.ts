import * as admin from "firebase-admin";
import {initScriptApp} from "./lib/target";
import {
  DEFAULT_BUCKET,
  ITEMS_COLLECTION,
  NOTIFICATIONS_COLLECTION,
  STORAGE_PREFIX,
  VOTES_SUBCOLLECTION,
} from "../src/teaching/library/constants";
import {describePurge} from "../src/teaching/purge";

// Apaga a biblioteca antiga (decisão do produto: recomeçar do zero): itens e
// votos, notificações da biblioteca e os arquivos do Storage. Mantém
// teaching_log, teaching_tags e usuários.
// Sem `--execute` só conta e imprime (padrão); nada é apagado.
async function main(): Promise<void> {
  const execute = process.argv.includes("--execute");
  initScriptApp(process.argv, {storageBucket: DEFAULT_BUCKET});
  const firestore = admin.firestore();
  const bucket = admin.storage().bucket();

  const items = await firestore.collection(ITEMS_COLLECTION).count().get();
  const votes = await firestore.collectionGroup(VOTES_SUBCOLLECTION).count().get();
  const notifications = await firestore.collection(NOTIFICATIONS_COLLECTION).count().get();
  const [objects] = await bucket.getFiles({prefix: `${STORAGE_PREFIX}/`});
  const counts = {
    items: items.data().count,
    votes: votes.data().count,
    notifications: notifications.data().count,
    objects: objects.length,
  };

  if (execute) {
    await firestore.recursiveDelete(firestore.collection(ITEMS_COLLECTION));
    await firestore.recursiveDelete(firestore.collection(NOTIFICATIONS_COLLECTION));
    await bucket.deleteFiles({prefix: `${STORAGE_PREFIX}/`});
  }
  console.log(describePurge(counts, execute));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
