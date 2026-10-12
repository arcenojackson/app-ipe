"use client";

import {
  GoogleAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth";
import {useRouter} from "next/navigation";
import {useEffect, useState, type FormEvent} from "react";
import {auth} from "@/core/firebase/client";
import {Button} from "@/core/ui/Button";
import {GlassCard} from "@/core/ui/GlassCard";
import {TextField} from "@/core/ui/TextField";
import {useAuth} from "./AuthContext";
import {authErrorMessage} from "./errors";

export function LoginForm() {
  const router = useRouter();
  const {state} = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (state.status === "signedIn") router.replace("/");
  }, [state.status, router]);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(authErrorMessage((e as {code?: string}).code ?? ""));
    } finally {
      setBusy(false);
    }
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    void run(() => signInWithEmailAndPassword(auth, email.trim(), password));
  }

  return (
    <GlassCard className="w-full max-w-sm">
      <h1 className="mb-1 text-2xl font-semibold">Portal de Ensino</h1>
      <p className="mb-6 text-sm text-white/70">
        Entre com a mesma conta do app IPE.
      </p>
      <form onSubmit={onSubmit} className="space-y-4">
        <TextField id="email" label="E-mail" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <TextField id="password" label="Senha" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        {error && <p role="alert" className="text-sm text-error">{error}</p>}
        <Button type="submit" disabled={busy} className="w-full">Entrar</Button>
      </form>
      <Button
        type="button"
        variant="text"
        disabled={busy}
        className="mt-3 w-full"
        onClick={() => run(() => signInWithPopup(auth, new GoogleAuthProvider()))}
      >
        Entrar com Google
      </Button>
    </GlassCard>
  );
}
