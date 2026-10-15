"use client";

import {useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "./Button";
import {GlassCard} from "./GlassCard";

export function AccessDenied() {
  const {refreshAccess, signOut} = useAuth();
  const [checking, setChecking] = useState(false);

  async function recheck() {
    setChecking(true);
    try {
      await refreshAccess();
    } finally {
      setChecking(false);
    }
  }

  return (
    <GlassCard className="mx-auto mt-10 max-w-lg">
      <h1 className="mb-2 text-xl font-semibold">Acesso restrito ao grupo de professores</h1>
      <p className="mb-6 text-sm text-white/70">
        Esta área é só para o grupo de professores da IPE. Se você deveria ter
        acesso, peça a um administrador que adicione você ao grupo e depois
        verifique novamente.
      </p>
      <div className="flex flex-wrap gap-2">
        <Button type="button" disabled={checking} onClick={recheck}>
          Verificar acesso novamente
        </Button>
        <Button type="button" variant="text" onClick={() => void signOut()}>
          Sair
        </Button>
      </div>
    </GlassCard>
  );
}
