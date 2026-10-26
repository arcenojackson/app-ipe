import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  startAfter,
  updateDoc,
  where,
  type DocumentData,
  type QueryConstraint,
  type QueryDocumentSnapshot,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {loadLibraryPage} from "../library/repository";
import {normalizeText} from "../library/text";
import {toPlanRow} from "../plan/convert";
import {toComment, toTopic} from "./convert";
import {
  commentEditPatch,
  newCommentPayload,
  newTopicPayload,
  topicEditPatch,
} from "./payloads";
import {topicQuery, type TopicFilters} from "./queries";
import {LIMITS} from "./types";
import type {Author, Comment, CommentInput, Ref, Topic, TopicInput} from "./types";

export type TopicCursor = QueryDocumentSnapshot<DocumentData>;

const topics = () => collection(db, "forum_topics");
const commentsOf = (topicId: string) => collection(db, "forum_topics", topicId, "comments");
const voteRef = (topicId: string, commentId: string, uid: string) =>
  doc(db, "forum_topics", topicId, "comments", commentId, "votes", uid);

function filterConstraints(filters: TopicFilters): {constraints: QueryConstraint[]; words: string[]} {
  const spec = topicQuery(filters);
  const constraints: QueryConstraint[] = [];
  if (spec.tagId) constraints.push(where("tagIds", "array-contains", spec.tagId));
  if (spec.token) constraints.push(where("searchTokens", "array-contains", spec.token));
  return {constraints, words: spec.words};
}

const matchesWords = (topic: Topic, words: string[]): boolean => {
  const title = normalizeText(topic.title);
  return words.every((word) => title.includes(word));
};

const toTopics = (docs: QueryDocumentSnapshot<DocumentData>[]): Topic[] =>
  docs.flatMap((d) => {
    const topic = toTopic(d.id, d.data());
    return topic ? [topic] : [];
  });

// Tópicos fixados (até 5), respeitando o assunto/busca ativos.
export async function loadPinnedTopics(filters: TopicFilters): Promise<Topic[]> {
  const {constraints, words} = filterConstraints(filters);
  const snapshot = await getDocs(
    query(topics(), where("deleted", "==", false), where("pinned", "==", true),
      ...constraints, limit(LIMITS.maxPinned))
  );
  return toTopics(snapshot.docs)
    .filter((t) => matchesWords(t, words))
    .sort((a, b) => b.lastActivityAt - a.lastActivityAt);
}

// Demais tópicos por atividade recente. Sem filtro, o servidor já exclui os
// fixados; com filtro, eles são descartados aqui (já aparecem no topo).
export async function loadTopicsPage(
  filters: TopicFilters,
  after: TopicCursor | null
): Promise<{topics: Topic[]; cursor: TopicCursor | null; done: boolean}> {
  const {constraints, words} = filterConstraints(filters);
  const unfiltered = constraints.length === 0;
  const all: QueryConstraint[] = [where("deleted", "==", false)];
  if (unfiltered) all.push(where("pinned", "==", false));
  all.push(...constraints, orderBy("lastActivityAt", "desc"));
  if (after) all.push(startAfter(after));
  all.push(limit(LIMITS.pageSize));
  const snapshot = await getDocs(query(topics(), ...all));
  const list = toTopics(snapshot.docs).filter((t) => !t.pinned && matchesWords(t, words));
  const last = snapshot.docs[snapshot.docs.length - 1] ?? null;
  return {topics: list, cursor: last, done: snapshot.docs.length < LIMITS.pageSize};
}

export async function loadTopic(id: string): Promise<Topic | null> {
  const snapshot = await getDoc(doc(topics(), id));
  return snapshot.exists() ? toTopic(snapshot.id, snapshot.data()) : null;
}

export async function loadComments(topicId: string): Promise<Comment[]> {
  const snapshot = await getDocs(
    query(commentsOf(topicId), orderBy("createdAt", "asc"), limit(LIMITS.maxComments))
  );
  return snapshot.docs.flatMap((d) => {
    const comment = toComment(topicId, d.id, d.data());
    return comment ? [comment] : [];
  });
}

// Voto do usuário em cada comentário (1 leitura por comentário votável).
export async function loadMyVotes(
  topicId: string,
  uid: string,
  commentIds: string[]
): Promise<Record<string, 1 | -1>> {
  const entries = await Promise.all(
    commentIds.map(async (id) => {
      const snapshot = await getDoc(voteRef(topicId, id, uid));
      const value = snapshot.data()?.value;
      return value === 1 || value === -1 ? ([id, value] as const) : null;
    })
  );
  return Object.fromEntries(entries.filter((e) => e !== null));
}

export async function createTopic(input: TopicInput, author: Author): Promise<string> {
  const ref = await addDoc(topics(), newTopicPayload(input, author, serverTimestamp()));
  return ref.id;
}

export async function editTopic(id: string, input: TopicInput): Promise<void> {
  await updateDoc(doc(topics(), id), topicEditPatch(input, serverTimestamp()));
}

export async function setTopicFlags(
  id: string,
  flags: Partial<{pinned: boolean; locked: boolean; deleted: boolean}>
): Promise<void> {
  await updateDoc(doc(topics(), id), flags);
}

export async function createComment(
  topicId: string,
  input: CommentInput,
  author: Author,
  parent: Comment | null
): Promise<void> {
  await addDoc(commentsOf(topicId), newCommentPayload(input, author, parent, serverTimestamp()));
}

export async function editComment(topicId: string, id: string, input: CommentInput): Promise<void> {
  await updateDoc(doc(commentsOf(topicId), id), commentEditPatch(input, serverTimestamp()));
}

export async function removeComment(topicId: string, id: string): Promise<void> {
  await updateDoc(doc(commentsOf(topicId), id), {deleted: true});
}

// value 0 retira o voto.
export async function setVote(
  topicId: string,
  commentId: string,
  uid: string,
  value: 1 | -1 | 0
): Promise<void> {
  const ref = voteRef(topicId, commentId, uid);
  if (value === 0) await deleteDoc(ref);
  else await setDoc(ref, {value});
}

// Só assuntos ativos (tags da Biblioteca), na ordem cadastrada.
export async function loadSubjectTags(): Promise<Array<{id: string; name: string}>> {
  const snapshot = await getDocs(
    query(collection(db, "teaching_tags"), where("kind", "==", "subject"), where("active", "==", true))
  );
  return snapshot.docs
    .map((d) => ({id: d.id, name: String(d.data().name ?? d.id), order: Number(d.data().order ?? 0)}))
    .sort((a, b) => a.order - b.order)
    .map(({id, name}) => ({id, name}));
}

// Documentos PUBLICADOS da Biblioteca, buscados pelo nome.
export async function loadPublishedDocs(search: string): Promise<Ref[]> {
  const filters = {typeTags: [], subjectTags: [], ageTags: [], text: search};
  const page = await loadLibraryPage(filters, null, 10);
  return page.items
    .filter((item) => item.type !== "folder")
    .map((item) => ({kind: "library" as const, id: item.id, label: item.name}));
}

export async function loadPlanLessons(): Promise<Ref[]> {
  const snapshot = await getDocs(query(collection(db, "teaching_plan"), orderBy("lesson", "asc")));
  return snapshot.docs.flatMap((d) => {
    const row = toPlanRow(d.id, d.data());
    return row ? [{kind: "plan" as const, id: row.id, label: `Aula ${row.lesson} — ${row.theme}`}] : [];
  });
}
