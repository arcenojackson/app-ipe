"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {positionLabel, type Round} from "../types";

interface Props {
  round: Round;
  busy: boolean;
  error: string | null;
  onSubmit: (choice: string) => void;
}

export function BallotStep({round, busy, error, onSubmit}: Props) {
  const [choice, setChoice] = useState<string | null>(null);
  const cargo = positionLabel(round.position);
  const single = round.type === "single";

  const options = single ?
    [
      {value: "yes", label: "Sim"},
      {value: "no", label: "Não"},
      {value: "blank", label: "Branco"},
    ] :
    [
      ...round.candidates.map((c) => ({value: c.id, label: c.name})),
      {value: "blank", label: "Branco"},
    ];

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">
        {single ?
          `${round.candidates[0]?.name} deve ser ${cargo}?` :
          `Votação para ${cargo}`}
      </h2>
      <div role="radiogroup" className="space-y-2">
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
        disabled={busy || choice === null}
        onClick={() => choice !== null && onSubmit(choice)}
      >
        Confirmar voto
      </Button>
    </div>
  );
}
