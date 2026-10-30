import * as admin from "firebase-admin";
import {initScriptApp} from "./lib/target";
import {
  ITEMS_COLLECTION,
  VOTES_SUBCOLLECTION,
} from "../src/teaching/library/constants";
import {planApprovedBy} from "../src/teaching/library/approvedBy";
import {toItem, toVote} from "../src/teaching/library/convert";

// Grava approvedBy (uids dos curadores que aprovaram a versão atual) nos
// itens JÁ publicados que ainda não têm o campo. Idempotente: itens com o
// campo são ignorados. Credenciais por ADC (gcloud auth application-default).
// Sem `--execute` só conta e imprime (padrão); nada é gravado.
async function main(): Promise<void> {
  const execute = process.argv.includes("--execute");
  initScriptApp(process.argv);
  const firestore = admin.firestore();
  console.log(execute ? "MODO: EXECUTAR (grava)" : "MODO: DRY-RUN (não grava)");

  const snapshot = await firestore
    .collection(ITEMS_COLLECTION)
    .where("status", "==", "published")
    .get();
  const entries = [];
  for (const doc of snapshot.docs) {
    const votes = await doc.ref.collection(VOTES_SUBCOLLECTION).get();
    entries.push({
      item: toItem(doc),
      votes: votes.docs.map((v) => toVote(v)),
      current: doc.get("approvedBy"),
    });
  }
  const plan = planApprovedBy(entries);
  const noVotes = entries.filter(
    (e) => !Array.isArray(e.current) && !plan.some((p) => p.itemId === e.item.id)
  );

  for (const {itemId, approvedBy} of plan) {
    console.log(`${execute ? "gravado" : "gravaria"} ${itemId}: ` +
      approvedBy.join(", "));
    // Sem updatedAt/updatedBy: é correção de metadado, não edição do item.
    if (execute) {
      await firestore
        .collection(ITEMS_COLLECTION)
        .doc(itemId)
        .update({approvedBy});
    }
  }
  console.log(
    `${snapshot.size} publicados lidos; ` +
    `${execute ? "atualizados" : "a atualizar"}: ${plan.length}; ` +
    `já com o campo: ${entries.filter((e) => Array.isArray(e.current)).length}; ` +
    `sem aprovações encontradas: ${noVotes.length}.`
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
