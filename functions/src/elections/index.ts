import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {pickOldest, removeCandidate, restartCargo} from "./cargoActions";
import {assertNotAnonymous} from "./common";
import {applyBoard, createElection, setElectionStatus} from "./lifecycle";
import {
  bumpVotedCount, castVote, closeScrutiny, startScrutiny,
} from "./scrutinies";
import {applyDueBoards} from "./transitions";
import {checkIn, reviewVoter} from "./voters";

const needAuth = (context: functions.https.CallableContext) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated", "Entre para continuar."
    );
  }
  return context.auth;
};

interface AuthLike {
  token: {firebase?: {sign_in_provider?: string}};
}

const isAnonymousAuth = (auth: AuthLike) =>
  auth.token.firebase?.sign_in_provider === "anonymous";

// Operações de diretor: exigem conta de verdade (nunca sessão anônima); a
// checagem de diretoria é feita dentro de cada função.
const needDirectorAuth = (context: functions.https.CallableContext) => {
  const auth = needAuth(context);
  assertNotAnonymous(isAnonymousAuth(auth));
  return auth;
};

export const electionCreate = functions.https.onCall((data, context) =>
  createElection(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionSetStatus = functions.https.onCall((data, context) =>
  setElectionStatus(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionCheckIn = functions.https.onCall((data, context) => {
  const auth = needAuth(context);
  return checkIn(admin.firestore(), {
    uid: auth.uid,
    isAnonymous: isAnonymousAuth(auth),
    email: auth.token.email,
    name: auth.token.name,
  }, data);
});

export const electionReviewVoter = functions.https.onCall((data, context) =>
  reviewVoter(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionStartScrutiny = functions.https.onCall((data, context) =>
  startScrutiny(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionCastVote = functions.https.onCall((data, context) =>
  castVote(admin.firestore(), needAuth(context).uid, data));

export const electionCloseScrutiny = functions.https.onCall((data, context) =>
  closeScrutiny(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionRemoveCandidate = functions.https.onCall(
  (data, context) =>
    removeCandidate(admin.firestore(), needDirectorAuth(context).uid, data)
);

export const electionRestartCargo = functions.https.onCall((data, context) =>
  restartCargo(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionPickOldest = functions.https.onCall((data, context) =>
  pickOldest(admin.firestore(), needDirectorAuth(context).uid, data));

export const electionApplyBoard =functions.https.onCall((data, context) =>
  applyBoard(admin.firestore(), needDirectorAuth(context).uid, data));

// Mandatos vão de 01/01 a 31/12: a diretoria eleita fica em espera
// (`boardTransitions`) e assume por esta rotina, todo 01/01 ao meio-dia.
export const electionApplyDueBoards = functions
  .region("us-central1")
  .pubsub.schedule("0 12 1 1 *")
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    const res = await applyDueBoards(admin.firestore());
    console.log(
      `Diretorias aplicadas: ${res.applied.length}; ` +
        `com falha: ${res.failed.length}`
    );
  });

// Contador ao vivo "X de Y votaram": roda fora da transação do voto.
export const electionVoteRecorded = functions.firestore
  .document("elections/{electionId}/rounds/{roundId}/voted/{voterId}")
  .onCreate((_snap, context) =>
    bumpVotedCount(
      admin.firestore(),
      context.params.electionId,
      context.params.roundId
    ));
