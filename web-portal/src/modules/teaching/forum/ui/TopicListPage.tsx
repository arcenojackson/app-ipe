"use client";

import Link from "next/link";
import {useEffect, useState, type FormEvent} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {loadPinnedTopics, loadSubjectTags, loadTopicsPage, type TopicCursor} from "../repository";
import type {Topic} from "../types";
import {formatDate} from "./format";

const LOAD_ERROR = "Não foi possível carregar o fórum.";

interface ListData {
  pinned: Topic[];
  topics: Topic[];
  cursor: TopicCursor | null;
  done: boolean;
}

// Lista do fórum: fixados no topo, depois por atividade recente. Assunto e
// busca por título são exclusivos (limite do Firestore).
export default function TopicListPage() {
  const [tags, setTags] = useState<Array<{id: string; name: string}>>([]);
  const [tagId, setTagId] = useState("");
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [data, setData] = useState<(ListData & {key: string}) | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [moreError, setMoreError] = useState<string | null>(null);
  const key = `${tagId}|${search}`;

  useEffect(() => {
    let cancelled = false;
    loadSubjectTags().then((list) => !cancelled && setTags(list)).catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const filters = {tagId, search};
    Promise.all([loadPinnedTopics(filters), loadTopicsPage(filters, null)])
      .then(([pinned, page]) => {
        if (cancelled) return;
        setError(null);
        setData({key: `${tagId}|${search}`, pinned, topics: page.topics, cursor: page.cursor, done: page.done});
      })
      .catch(() => !cancelled && setError(LOAD_ERROR));
    return () => {
      cancelled = true;
    };
  }, [tagId, search]);

  function chooseTag(id: string) {
    setTagId(id);
    setSearch("");
    setSearchInput("");
  }

  function submitSearch(event: FormEvent) {
    event.preventDefault();
    setTagId("");
    setSearch(searchInput.trim());
  }

  async function loadMore() {
    if (!data) return;
    setMoreError(null);
    try {
      const page = await loadTopicsPage({tagId, search}, data.cursor);
      setData({...data, topics: [...data.topics, ...page.topics], cursor: page.cursor, done: page.done});
    } catch {
      setMoreError(LOAD_ERROR);
    }
  }

  const ready = data !== null && data.key === key;
  const nameOf = (id: string) => tags.find((t) => t.id === id)?.name ?? id;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold">Fórum</h1>
        <Link
          href="/ensino/forum/novo"
          className="inline-flex items-center justify-center rounded-button bg-primary px-5 py-3 font-semibold text-on-primary hover:brightness-125"
        >
          Novo tópico
        </Link>
      </div>

      <form onSubmit={submitSearch} className="flex flex-wrap items-end gap-3">
        <div className="min-w-[14rem] flex-1">
          <TextField
            id="forum-search"
            label="Buscar no título"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
          />
        </div>
        <Button type="submit">Buscar</Button>
        <label className="block text-sm text-white/70" htmlFor="forum-tag">
          Assunto
          <select
            id="forum-tag"
            value={tagId}
            onChange={(e) => chooseTag(e.target.value)}
            className="mt-1 block rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface"
          >
            <option value="">Todos os assuntos</option>
            {tags.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
        </label>
      </form>

      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {!ready && !error && <p className="text-white/70">Carregando…</p>}
      {ready && data.pinned.length + data.topics.length === 0 && (
        <p className="rounded-card bg-surface-elevated p-6">Nenhum tópico ainda.</p>
      )}
      {ready && (
        <ul className="space-y-2">
          {[...data.pinned, ...data.topics].map((topic) => (
            <li key={topic.id} className="rounded-card bg-surface-elevated p-4">
              <Link href={`/ensino/forum/${topic.id}`} className="text-lg font-semibold hover:underline">
                {topic.title}
              </Link>
              <p className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-white/60">
                {topic.pinned && <span className="font-medium text-secondary">Fixado</span>}
                {topic.locked && <span className="font-medium">Trancado</span>}
                <span>{topic.authorName}</span>
                <span>{topic.commentCount} {topic.commentCount === 1 ? "comentário" : "comentários"}</span>
                <span>Atividade em {formatDate(topic.lastActivityAt)}</span>
                {topic.tagIds.map((id) => (
                  <span key={id} className="rounded-full bg-white/10 px-2 py-0.5">{nameOf(id)}</span>
                ))}
              </p>
            </li>
          ))}
        </ul>
      )}
      {ready && !data.done && (
        <Button type="button" variant="text" onClick={() => void loadMore()}>
          Carregar mais
        </Button>
      )}
      {moreError && <p role="alert" className="text-sm text-error">{moreError}</p>}
    </div>
  );
}
