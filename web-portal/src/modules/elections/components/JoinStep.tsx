"use client";

import {useState, type FormEvent} from "react";
import {authErrorMessage} from "@/core/auth/errors";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {
  checkIn,
  errorMessage,
  signInGuest,
  signInWithGoogle,
  signInWithPassword,
} from "../data/electionClient";

type Mode = "choose" | "login" | "guest";

interface Props {
  electionId: string;
  /** Já há sessão anônima sem check-in: só falta o formulário de convidado. */
  anonymousSession: boolean;
  /** Sessão com conta do app: o check-in automático está em andamento. */
  verifying: boolean;
}

export function JoinStep({electionId, anonymousSession, verifying}: Props) {
  const [mode, setMode] = useState<Mode>(anonymousSession ? "guest" : "choose");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [guestEmail, setGuestEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(action: () => Promise<unknown>, onError = errorMessage) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(onError(e));
    } finally {
      setBusy(false);
    }
  }

  const authMessage = (e: unknown) =>
    authErrorMessage((e as {code?: string}).code ?? "");

  if (verifying) {
    return <p className="text-sm text-white/70">Verificando sua presença...</p>;
  }

  if (mode === "choose") {
    return (
      <div className="space-y-3">
        <Button type="button" className="w-full" onClick={() => setMode("login")}>
          Entrar com a conta do app
        </Button>
        <Button type="button" variant="text" className="w-full" onClick={() => setMode("guest")}>
          Votar sem conta
        </Button>
      </div>
    );
  }

  if (mode === "login") {
    return (
      <div className="space-y-4">
        <form
          className="space-y-4"
          onSubmit={(event: FormEvent) => {
            event.preventDefault();
            void run(() => signInWithPassword(email, password), authMessage);
          }}
        >
          <TextField id="email" label="E-mail" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
          <TextField id="password" label="Senha" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
          {error && <p role="alert" className="text-sm text-error">{error}</p>}
          <Button type="submit" disabled={busy} className="w-full">Entrar</Button>
        </form>
        <Button type="button" variant="text" disabled={busy} className="w-full" onClick={() => run(() => signInWithGoogle(), authMessage)}>
          Entrar com Google
        </Button>
        <Button type="button" variant="text" className="w-full" onClick={() => { setError(null); setMode("choose"); }}>
          Voltar
        </Button>
      </div>
    );
  }

  return (
    <form
      className="space-y-4"
      onSubmit={(event: FormEvent) => {
        event.preventDefault();
        void run(async () => {
          if (!anonymousSession) await signInGuest();
          await checkIn(electionId, {name: name.trim(), email: guestEmail.trim()});
        });
      }}
    >
      <TextField id="guest-name" label="Seu nome" required value={name} onChange={(e) => setName(e.target.value)} />
      <TextField id="guest-email" label="Seu e-mail" type="email" required value={guestEmail} onChange={(e) => setGuestEmail(e.target.value)} />
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      <Button type="submit" disabled={busy} className="w-full">Continuar</Button>
      {!anonymousSession && (
        <Button type="button" variant="text" className="w-full" onClick={() => { setError(null); setMode("choose"); }}>
          Voltar
        </Button>
      )}
    </form>
  );
}
