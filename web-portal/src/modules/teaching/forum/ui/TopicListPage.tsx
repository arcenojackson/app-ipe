"use client";

import Link from "next/link";
import {useEffect, useState, type FormEvent} from "react";
import {Button} from "@/core/ui/Button";
import {Icon} from "@/core/ui/icons";
import {loadPinnedTopics, loadSubjectTags, loadTopicsPage, type TopicCursor} from "../repository";
import type {Topic} from "../types";
import {formatDate} from "./format";
import {Avatar, Pill, SubjectMenu} from "./parts";

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
  const [retry, setRetry] = useState(0);
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
  }, [tagId, search, retry]);

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

  function row(topic: Topic, pinned: boolean) {
    return (
      <li key={topic.id}>
        <Link
          href={`/ensino/forum/${topic.id}`}
          className={`grid grid-cols-[2.25rem_minmax(0,1fr)_auto] items-center gap-3 border-t border-white/5 px-4 py-3 hover:bg-white/5 ${
            pinned ? "bg-secondary/10 shadow-[inset_3px_0_0_var(--color-secondary)]" : ""
          }`}
        >
          <Avatar name={topic.authorName} />
          <span className="min-w-0">
            <span className="block truncate font-semibold">{topic.title}</span>
            <span className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-white/60">
              {topic.pinned && <Pill tone="pinned">Fixado</Pill>}
              {topic.locked && <Pill>Trancado</Pill>}
              {topic.tagIds.map((id) => <Pill key={id} tone="subject">{nameOf(id)}</Pill>)}
              <span>{topic.authorName}</span>
              <span>· atividade em {formatDate(topic.lastActivityAt)}</span>
            </span>
          </span>
          <span className="hidden min-w-[3.5rem] flex-col items-center rounded-xl bg-surface-elevated px-2 py-1 text-[11px] text-white/60 sm:flex">
            <b className="text-base text-on-surface">{topic.commentCount}</b>
            {topic.commentCount === 1 ? "comentário" : "comentários"}
          </span>
        </Link>
      </li>
    );
  }

  const none = ready && data.pinned.length + data.topics.length === 0;
  const filtered = tagId !== "" || search !== "";

  return (
    <div className="mx-auto max-w-[820px] space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <form onSubmit={submitSearch} className="flex min-w-[14rem] flex-1 items-center gap-2 rounded-full bg-surface-elevated pl-4 pr-1.5">
          <Icon name="search" className="h-4 w-4 text-white/60" />
          <input
            id="forum-search"
            type="search"
            aria-label="Buscar no título"
            placeholder="Buscar no título…"
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            className="min-w-0 flex-1 bg-transparent py-2.5 text-sm outline-none"
          />
          <button type="submit" className="rounded-full px-3 py-1.5 text-sm hover:bg-white/10">Buscar</button>
        </form>
        <Link
          href="/ensino/forum/novo"
          className="inline-flex items-center gap-2 rounded-full bg-secondary px-5 py-2.5 font-semibold text-white hover:brightness-125"
        >
          <Icon name="plus" className="h-4 w-4" />
          Novo tópico
        </Link>
      </div>
      <div>
        <h1 className="text-2xl font-semibold">Fórum</h1>
        <p className="text-white/60">Conversa entre professores e curadores.</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <SubjectMenu subjects={tags} value={tagId ? [tagId] : []} onChange={(ids) => chooseTag(ids[0] ?? "")} />
        <span className="ml-auto text-xs text-white/60">Assunto e busca não se combinam</span>
      </div>

      {error && (
        <div role="alert" className="rounded-card bg-surface p-6 text-center text-error">
          {error}
          <div className="mt-3">
            <Button type="button" variant="text" onClick={() => setRetry((n) => n + 1)}>Tentar de novo</Button>
          </div>
        </div>
      )}
      {!ready && !error && (
        <div className="overflow-hidden rounded-card bg-surface" aria-busy="true">
          <p className="sr-only">Carregando…</p>
          {[0, 1, 2].map((i) => <div key={i} className="h-16 animate-pulse border-t border-white/5 bg-white/5 first:border-0" />)}
        </div>
      )}
      {none && (
        <div className="rounded-card bg-surface p-8 text-center text-white/60">
          <p className="font-semibold text-on-surface">Nenhum tópico ainda.</p>
          <p>{filtered ? "Nada encontrado com este filtro." : "Comece a conversa com os colegas."}</p>
          {filtered && (
            <div className="mt-3">
              <Button type="button" variant="text" onClick={() => { chooseTag(""); setRetry((n) => n + 1); }}>Limpar filtro</Button>
            </div>
          )}
        </div>
      )}
      {ready && !none && (
        <div className="overflow-hidden rounded-card bg-surface">
          {data.pinned.length > 0 && (
            <>
              <p className="bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-white/60">Fixados</p>
              <ul>{data.pinned.map((t) => row(t, true))}</ul>
              <p className="border-t border-white/5 bg-white/5 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-white/60">Recentes</p>
            </>
          )}
          <ul>{data.topics.map((t) => row(t, false))}</ul>
        </div>
      )}
      {ready && !data.done && (
        <div className="text-center">
          <button type="button" onClick={() => void loadMore()} className="rounded-full border border-white/10 px-5 py-2 text-sm hover:bg-white/10">
            Carregar mais
          </button>
        </div>
      )}
      {moreError && <p role="alert" className="text-sm text-error">{moreError}</p>}
    </div>
  );
}
