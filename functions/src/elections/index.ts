import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {assertNotAnonymous} from "./common";
import {applyBoard, setElectionStatus} from "./lifecycle";
import {bumpVotedCount, castVote, closeRound, openRound} from "./rounds";
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

// Operações de admin: exigem conta de verdade (nunca sessão anônima).
const needAdminAuth = (context: functions.https.CallableContext) => {
  const auth = needAuth(context);
  assertNotAnonymous(isAnonymousAuth(auth));
  return auth;
};

export const electionSetStatus = functions.https.onCall((data, context) =>
  setElectionStatus(admin.firestore(), needAdminAuth(context).uid, data));

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
  reviewVoter(admin.firestore(), needAdminAuth(context).uid, data));

export const electionOpenRound = functions.https.onCall((data, context) =>
  openRound(admin.firestore(), needAdminAuth(context).uid, data));

export const electionCastVote = functions.https.onCall((data, context) =>
  castVote(admin.firestore(), needAuth(context).uid, data));

export const electionCloseRound = functions.https.onCall((data, context) =>
  closeRound(admin.firestore(), needAdminAuth(context).uid, data));

export const electionApplyBoard = functions.https.onCall((data, context) =>
  applyBoard(admin.firestore(), needAdminAuth(context).uid, data));

// Contador ao vivo "X de Y votaram": roda fora da transação do voto.
export const electionVoteRecorded = functions.firestore
  .document("elections/{electionId}/rounds/{roundId}/voted/{voterId}")
  .onCreate((_snap, context) =>
    bumpVotedCount(
      admin.firestore(),
      context.params.electionId,
      context.params.roundId
    ));
