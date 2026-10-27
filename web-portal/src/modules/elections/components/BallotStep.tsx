"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {filterOptions} from "../filterOptions";
import {positionLabel, type Round} from "../types";

interface Props {
  round: Round;
  busy: boolean;
  error: string | null;
  onSubmit: (choice: string) => void;
}

export function BallotStep({round, busy, error, onSubmit}: Props) {
  const [choice, setChoice] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const visible = round.number === 1 ?
    filterOptions(round.options, search) :
    round.options;
  const options = [
    ...visible.map((o) => ({value: o.id, label: o.name})),
    {value: "blank", label: "Branco"},
  ];

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">
        {`Votação para ${positionLabel(round.position)} — ${round.number}º escrutínio`}
      </h2>
      {round.number === 1 && (
        <TextField
          id="ballot-search"
          label="Buscar por nome"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      )}
      <div role="radiogroup" className="max-h-80 space-y-2 overflow-y-auto">
        {options.map((option) => (
          <label
            key={option.value}
            className="flex cursor-pointer items-center gap-3 rounded-card bg-white/5 px-4 py-3"
          >
            <input
              type="radio"
              name="choice"
              value={option.value}
              checked={choice === option.value}
              onChange={() => setChoice(option.value)}
            />
            {option.label}
          </label>
        ))}
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      <Button
        type="button"
        className="w-full"
        disabled={choice === null}
        loading={busy}
        onClick={() => choice !== null && onSubmit(choice)}
      >
        Confirmar voto
      </Button>
    </div>
  );
}
