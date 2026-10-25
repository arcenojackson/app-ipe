import * as admin from "firebase-admin";
import {TAG_SEED} from "../src/teaching/tagSeed";

// Cria as tags iniciais em teaching_tags que ainda não existem. Nunca
// sobrescreve uma tag existente (edições manuais no banco são preservadas).
// Com `--dry-run` nada é gravado: apenas imprime o que seria criado.
async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  console.log(dryRun ? "Modo DRY-RUN: nada será gravado." : "Gravando tags.");
  admin.initializeApp({projectId: "app-ipe"});
  const collection = admin.firestore().collection("teaching_tags");
  let created = 0;
  let skipped = 0;
  for (const tag of TAG_SEED) {
    const {id, ...data} = tag;
    const ref = collection.doc(id);
    if ((await ref.get()).exists) {
      skipped++;
      continue;
    }
    console.log(`${dryRun ? "criaria" : "criando"}: ${id} (${data.name})`);
    if (!dryRun) await ref.create(data);
    created++;
  }
  console.log(`${created} ${dryRun ? "a criar" : "criadas"}, ${skipped} já existiam.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
