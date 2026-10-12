import * as admin from "firebase-admin";
import {
  computeTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

async function main(): Promise<void> {
  admin.initializeApp({projectId: "app-ipe"});
  const snapshot = await admin.firestore().collection("users").get();
  let updated = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    const claims = computeTeachingClaims(doc.data());
    if (Object.keys(claims).length === 0) continue;
    try {
      const user = await admin.auth().getUser(doc.id);
      await admin
        .auth()
        .setCustomUserClaims(doc.id, mergeTeachingClaims(user.customClaims, claims));
      updated++;
    } catch (error) {
      failed++;
      console.error(`Falha em ${doc.id}:`, (error as Error).message);
    }
  }
  console.log(`Claims gravadas: ${updated}. Falhas: ${failed}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
