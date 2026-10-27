"use client";

import {useState, type FormEvent} from "react";
import {authErrorMessage} from "@/core/auth/errors";
import {Button} from "@/core/ui/Button";
import {LoadingText} from "@/core/ui/Spinner";
import {TextField} from "@/core/ui/TextField";
import {
  checkIn,
  errorMessage,
  signInWithGoogle,
  signInWithPassword,
} from "../data/electionClient";

type Mode = "choose" | "login";

interface Props {
  electionId: string;
  /**
   * Já há uma conta entrada, mas o servidor não achou o nome dela: só falta
   * pedir o nome.
   */
  needsName: boolean;
  /** Conta entrada: o check-in automático está em andamento. */
  verifying: boolean;
}

export function JoinStep({electionId, needsName, verifying}: Props) {
  const [mode, setMode] = useState<Mode>("choose");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
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
    return <LoadingText>Verificando sua presença...</LoadingText>;
  }

  if (needsName) {
    return (
      <form
        className="space-y-4"
        onSubmit={(event: FormEvent) => {
          event.preventDefault();
          void run(() => checkIn(electionId, {name: name.trim()}));
        }}
      >
        <p className="text-sm text-white/70">
          Não encontramos o nome da sua conta. Informe como você se chama.
        </p>
        <TextField id="voter-name" label="Seu nome" required value={name} onChange={(e) => setName(e.target.value)} />
        {error && <p role="alert" className="text-sm text-error">{error}</p>}
        <Button type="submit" loading={busy} className="w-full">Continuar</Button>
      </form>
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
          <Button type="submit" loading={busy} className="w-full">Entrar</Button>
        </form>
        <Button type="button" variant="text" className="w-full" onClick={() => { setError(null); setMode("choose"); }}>
          Voltar
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-white/70">
        Para votar, entre com a sua conta. Quem ainda não tem cadastro é
        cadastrado automaticamente.
      </p>
      <Button type="button" className="w-full" loading={busy} onClick={() => run(() => signInWithGoogle(), authMessage)}>
        Entrar com Google
      </Button>
      <Button type="button" variant="text" className="w-full" onClick={() => setMode("login")}>
        Entrar com e-mail e senha
      </Button>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
    </div>
  );
}
