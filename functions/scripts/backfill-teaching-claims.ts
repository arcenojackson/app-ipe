import * as admin from "firebase-admin";
import {initScriptApp} from "./lib/target";
import {
  BackfillCounts,
  formatChangeLine,
  formatDryRunSummary,
  formatMissingLine,
  formatMode,
  formatUserLine,
  isAuditedUser,
  isDryRun,
} from "../src/teaching/backfillAudit";
import {
  claimsEqual,
  computeTeachingClaims,
  currentTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

// Reconciliação: compara as claims desejadas (users/{uid}) com as claims
// atuais do Auth e corrige qualquer divergência, inclusive removendo claims
// de quem perdeu o papel.
// Com `--dry-run` nada é gravado: apenas imprime uma auditoria.
async function main(): Promise<void> {
  const dryRun = isDryRun(process.argv);
  console.log(formatMode(dryRun));
  initScriptApp(process.argv);
  const snapshot = await admin.firestore().collection("users").get();
  let updated = 0;
  let unchanged = 0;
  let skipped = 0;
  let failed = 0;

  const counts: BackfillCounts = {
    read: snapshot.size,
    admins: 0,
    teachers: 0,
    curators: 0,
    wouldChange: 0,
    unchanged: 0,
    noAuthAccount: 0,
    failed: 0,
  };
  const changeLines: string[] = [];
  const missingLines: string[] = [];

  if (dryRun) {
    console.log("Usuários com is_admin ou teaching_role:");
    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.is_admin === true) counts.admins++;
      if (data.teaching_role === "teacher") counts.teachers++;
      if (data.teaching_role === "curator") counts.curators++;
      if (isAuditedUser(data)) console.log(formatUserLine(doc.id, data));
    }
  }

  for (const doc of snapshot.docs) {
    try {
      const desired = computeTeachingClaims(doc.data());
      const user = await admin.auth().getUser(doc.id);
      const current = currentTeachingClaims(user.customClaims);
      if (claimsEqual(desired, current)) {
        unchanged++;
        continue;
      }
      if (dryRun) {
        changeLines.push(
          formatChangeLine(doc.id, user.email, current, desired)
        );
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
        missingLines.push(formatMissingLine(doc.id, doc.data()));
        continue;
      }
      failed++;
      console.error(`Falha em ${doc.id}:`, (error as Error).message);
    }
  }

  if (dryRun) {
    counts.wouldChange = changeLines.length;
    counts.unchanged = unchanged;
    counts.noAuthAccount = skipped;
    counts.failed = failed;
    console.log("Claims que mudariam:");
    for (const line of changeLines) console.log(line);
    if (changeLines.length === 0) console.log("  (nenhuma)");
    console.log("Usuários sem conta no Auth:");
    for (const line of missingLines) console.log(line);
    if (missingLines.length === 0) console.log("  (nenhum)");
    for (const line of formatDryRunSummary(counts)) console.log(line);
    return;
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
