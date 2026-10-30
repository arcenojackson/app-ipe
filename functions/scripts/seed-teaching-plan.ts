import * as admin from "firebase-admin";
import {initScriptApp} from "./lib/target";
import {PLAN_SEED} from "../src/teaching/planSeed";

// Cria as 52 linhas do plano pedagógico em teaching_plan que ainda não
// existem (nunca sobrescreve edições). `--dry-run` só imprime.
async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  console.log(dryRun ? "Modo DRY-RUN: nada será gravado." : "Gravando o plano.");
  initScriptApp(process.argv);
  const collection = admin.firestore().collection("teaching_plan");
  let created = 0;
  let skipped = 0;
  for (const row of PLAN_SEED) {
    const {id, ...data} = row;
    const ref = collection.doc(id);
    if ((await ref.get()).exists) {
      skipped++;
      continue;
    }
    if (!dryRun) {
      await ref.create({
        ...data,
        updatedBy: "seed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    created++;
  }
  console.log(`${created} ${dryRun ? "a criar" : "criadas"}, ${skipped} já existiam.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
