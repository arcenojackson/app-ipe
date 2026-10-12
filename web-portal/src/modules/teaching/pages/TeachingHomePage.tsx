"use client";

import Link from "next/link";
import {useAuth} from "@/core/auth/AuthContext";
import {Card} from "@/core/ui/Card";

export default function TeachingHomePage() {
  const {state} = useAuth();
  if (state.status !== "signedIn") return null;
  const {claims, user} = state;
  const roleLabel = claims.admin
    ? "Administrador"
    : claims.teachingRole === "curator"
      ? "Curador"
      : "Professor";

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Olá, {user.displayName ?? user.email}</h1>
      <p className="text-white/70">Seu papel no grupo: {roleLabel}</p>
      <Card>
        <h2 className="font-semibold">Biblioteca de materiais</h2>
        <p className="text-sm text-white/70">Em breve: aulas, planos e bibliografia por faixa etária.</p>
      </Card>
      <Card>
        <h2 className="font-semibold">Fórum</h2>
        <p className="text-sm text-white/70">Em breve: dúvidas e conversas entre os professores.</p>
      </Card>
      {claims.admin && (
        <Link href="/ensino/admin" className="text-secondary underline">
          Gerenciar o grupo de professores
        </Link>
      )}
    </div>
  );
}
