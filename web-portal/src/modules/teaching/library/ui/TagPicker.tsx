"use client";

import {TAGS_LOAD_HINT, type ItemTags, type Tag} from "../tags";
import {TagMenus} from "./TagMenus";

// Escolha de tags no envio/edição: mesmo seletor da Biblioteca; só oferece as
// tags ativas.
export function TagPicker({
  tags,
  value,
  onChange,
  error,
  loadError,
}: {
  tags: Tag[];
  value: ItemTags;
  onChange: (next: ItemTags) => void;
  error?: string | null;
  // Falha ao carregar as tags (de useTags).
  loadError?: string | null;
}) {
  return (
    <div className="flex flex-col gap-3">
      {loadError && <p role="alert" className="text-sm text-error">{`${loadError} ${TAGS_LOAD_HINT}`}</p>}
      <TagMenus tags={tags} value={value} onChange={onChange} />
      {error && (
        <p role="alert" className="text-sm text-error">
          {error}
        </p>
      )}
    </div>
  );
}
