import * as admin from "firebase-admin";
import {
  claimsEqual,
  computeTeachingClaims,
  currentTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

// Reconciliação: compara as claims desejadas (users/{uid}) com as claims
// atuais do Auth e corrige qualquer divergência, inclusive removendo claims
// de quem perdeu o papel.
async function main(): Promise<void> {
  admin.initializeApp({projectId: "app-ipe"});
  const snapshot = await admin.firestore().collection("users").get();
  let updated = 0;
  let unchanged = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    try {
      const desired = computeTeachingClaims(doc.data());
      const user = await admin.auth().getUser(doc.id);
      const current = currentTeachingClaims(user.customClaims);
      if (claimsEqual(desired, current)) {
        unchanged++;
        continue;
      }
      await admin
        .auth()
        .setCustomUserClaims(
          doc.id,
          mergeTeachingClaims(user.customClaims, desired)
        );
      updated++;
    } catch (error) {
      if ((error as {code?: string}).code === "auth/user-not-found") {
        skipped++;
        continue;
      }
      failed++;
      console.error(`Falha em ${doc.id}:`, (error as Error).message);
    }
  }
  console.log(
    `Atualizadas: ${updated}. Sem mudança: ${unchanged}. ` +
      `Sem conta no Auth: ${skipped}. Falhas: ${failed}.`
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
