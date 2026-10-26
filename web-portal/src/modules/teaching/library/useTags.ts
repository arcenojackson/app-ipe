"use client";

import {useEffect, useMemo, useState} from "react";
import {loadTags} from "./tagsRepository";
import type {Tag, TagKind} from "./tags";

// Uma leitura por sessão: as tags mudam raramente e são editadas à mão.
let cache: Promise<Tag[]> | null = null;

function sharedTags(): Promise<Tag[]> {
  if (!cache) {
    cache = loadTags().catch((error) => {
      cache = null;
      throw error;
    });
  }
  return cache;
}

export function useTags() {
  const [tags, setTags] = useState<Tag[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    sharedTags()
      .then((list) => active && setTags(list))
      .catch(() => active && setError("Não foi possível carregar as tags."));
    return () => {
      active = false;
    };
  }, []);

  const byId = useMemo(() => new Map((tags ?? []).map((t) => [t.id, t])), [tags]);
  const activeOf = (kind: TagKind): Tag[] =>
    (tags ?? []).filter((t) => t.kind === kind && t.active);

  return {tags, error, byId, active: activeOf};
}
