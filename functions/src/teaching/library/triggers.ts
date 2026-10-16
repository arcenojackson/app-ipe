// Os gatilhos são finos de propósito: a lógica é testada em processVote.ts e
// processItemChange.ts com portas em memória, e os adaptadores no emulador.
// A fiação dos gatilhos só é exercitada em produção (verificação do Plano B).
import * as functions from "firebase-functions/v1";
import {buildDeps} from "./buildDeps";
import {toItem} from "./convert";
import {processItemChange, processItemCreated} from "./processItemChange";
import {processVote} from "./processVote";

// Retentativa ligada: as operações são idempotentes (ver processVote.ts).
const base = functions.runWith({
  failurePolicy: true,
  timeoutSeconds: 540,
});

export const onTeachingVoteCreated = base.firestore
  .document("teaching_items/{itemId}/votes/{voteId}")
  .onCreate(async (_snapshot, context) => {
    const {itemId, voteId} = context.params;
    await processVote(buildDeps(), itemId, voteId);
    return null;
  });

export const onTeachingItemCreated = base.firestore
  .document("teaching_items/{itemId}")
  .onCreate(async (snapshot) => {
    await processItemCreated(buildDeps(), toItem(snapshot));
    return null;
  });

export const onTeachingItemUpdated = base.firestore
  .document("teaching_items/{itemId}")
  .onUpdate(async (change) => {
    await processItemChange(
      buildDeps(),
      toItem(change.before),
      toItem(change.after)
    );
    return null;
  });
