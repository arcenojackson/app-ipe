"use client";

import {TAG_KIND_STYLE} from "../tagKindStyle";
import {TAGS_LOAD_HINT, TAG_FIELD, TAG_KINDS, TAG_KIND_LABEL, type ItemTags, type Tag} from "../tags";

// Escolha de tags (três grupos); só oferece as tags ativas.
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
  const toggle = (field: keyof ItemTags, id: string) => {
    const current = value[field];
    const next = current.includes(id) ? current.filter((x) => x !== id) : [...current, id];
    onChange({...value, [field]: next});
  };

  return (
    <div className="flex flex-col gap-3">
      {loadError && <p role="alert" className="text-sm text-error">{`${loadError} ${TAGS_LOAD_HINT}`}</p>}
      {TAG_KINDS.map((kind) => {
        const field = TAG_FIELD[kind];
        return (
          <fieldset key={kind} className="flex flex-col gap-1">
            <legend className="mb-1 flex items-center gap-2 text-sm font-semibold">
              <span aria-hidden className={`h-2.5 w-2.5 rounded-full ${TAG_KIND_STYLE[kind].dot}`} />
              {TAG_KIND_LABEL[kind]}
            </legend>
            <div className="flex flex-wrap gap-x-4 gap-y-1">
              {tags
                .filter((t) => t.kind === kind && t.active)
                .map((t) => (
                  <label key={t.id} className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={value[field].includes(t.id)}
                      onChange={() => toggle(field, t.id)}
                    />
                    {t.name}
                  </label>
                ))}
            </div>
          </fieldset>
        );
      })}
      {error && (
        <p role="alert" className="text-sm text-error">
          {error}
        </p>
      )}
    </div>
  );
}
