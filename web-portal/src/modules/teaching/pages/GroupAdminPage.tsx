"use client";

import {useEffect, useMemo, useState} from "react";
import {Card} from "@/core/ui/Card";
import {TextField} from "@/core/ui/TextField";
import {
  ROLE_LABELS,
  filterMembers,
  type MemberRow,
  type TeachingRoleValue,
} from "../data/memberRows";
import {listMembers, setTeachingRole} from "../data/membersRepository";

export default function GroupAdminPage() {
  const [members, setMembers] = useState<MemberRow[] | null>(null);
  const [term, setTerm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState<ReadonlySet<string>>(new Set());

  useEffect(() => {
    let active = true;
    listMembers()
      .then((rows) => active && setMembers(rows))
      .catch(() => active && setError("Não foi possível carregar os usuários."));
    return () => {
      active = false;
    };
  }, []);

  const visible = useMemo(() => filterMembers(members ?? [], term), [members, term]);

  function patch(id: string, role: TeachingRoleValue) {
    setMembers((current) =>
      current?.map((m) => (m.id === id ? {...m, teachingRole: role} : m)) ?? null
    );
  }

  function markSaving(id: string, on: boolean) {
    setSaving((current) => {
      const next = new Set(current);
      if (on) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  async function onChangeRole(member: MemberRow, role: TeachingRoleValue) {
    const previous = member.teachingRole;
    setError(null);
    patch(member.id, role);
    markSaving(member.id, true);
    try {
      await setTeachingRole(member.id, role);
    } catch {
      patch(member.id, previous);
      setError(`Não foi possível salvar o papel de ${member.name}. Tente novamente.`);
    } finally {
      markSaving(member.id, false);
    }
  }

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Grupo de professores</h1>
      <p className="text-sm text-white/70">
        Defina quem faz parte do grupo. A mudança vale quando a pessoa abrir ou
        recarregar o portal (ou usar &quot;Verificar acesso novamente&quot;).
      </p>
      <TextField
        id="search"
        label="Buscar por nome ou e-mail"
        value={term}
        onChange={(e) => setTerm(e.target.value)}
      />
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {members === null && !error && <p className="text-white/70">Carregando…</p>}
      <ul className="space-y-2">
        {visible.map((member) => (
          <li key={member.id}>
            <Card className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="font-semibold">{member.name}</p>
                <p className="text-sm text-white/70">{member.email}</p>
                <div className="mt-1 flex gap-2 text-xs">
                  {member.isAdmin && <span className="rounded-button bg-primary/40 px-2 py-0.5">Admin</span>}
                  {member.isPending && <span className="rounded-button bg-white/10 px-2 py-0.5">Pendente</span>}
                </div>
              </div>
              <select
                aria-label={`Papel de ${member.name}`}
                value={member.teachingRole}
                disabled={saving.has(member.id)}
                onChange={(e) => void onChangeRole(member, e.target.value as TeachingRoleValue)}
                className="rounded-input border border-white/5 bg-surface px-3 py-2 text-on-surface focus:border-primary focus:outline-none"
              >
                {(Object.keys(ROLE_LABELS) as TeachingRoleValue[]).map((role) => (
                  <option key={role} value={role}>{ROLE_LABELS[role]}</option>
                ))}
              </select>
            </Card>
          </li>
        ))}
      </ul>
    </div>
  );
}
