"use client";

import Link from "next/link";
import {usePathname, useRouter} from "next/navigation";
import {useEffect, type ReactNode} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {
  isPathAllowed,
  moduleForPath,
  portalModules,
  visibleNavGroups,
} from "@/core/modules/registry";
import type {PortalModule} from "@/core/modules/types";
import {AccessDenied} from "./AccessDenied";
import {Button} from "./Button";
import {Icon} from "./icons";

export function PortalShell({
  children,
  modules = portalModules,
}: {
  children: ReactNode;
  modules?: PortalModule[];
}) {
  const {state, signOut} = useAuth();
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    if (state.status === "signedOut") router.replace("/login");
  }, [state.status, router]);

  if (state.status !== "signedIn") {
    return <p className="p-6 text-white/70">Carregando…</p>;
  }

  const groups = visibleNavGroups(modules, state.claims);
  const allowed = isPathAllowed(modules, pathname, state.claims);

  // O menu e a marca "Portal de Ensino" são do módulo de ensino. Rotas de
  // módulos sem itens de menu (ex.: /eleicoes) abrem sem a barra lateral.
  const showMenu = (moduleForPath(modules, pathname)?.navItems.length ?? 0) > 0;
  if (!showMenu) {
    return <main className="min-h-screen p-6">{allowed ? children : <AccessDenied />}</main>;
  }

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <aside className="border-b border-white/5 bg-surface p-4 md:min-h-screen md:w-64 md:border-b-0 md:border-r">
        <p className="mb-5 flex items-center gap-2.5 px-2 text-base font-bold">
          <span aria-hidden className="h-7 w-7 rounded-[9px] bg-gradient-to-br from-primary to-secondary" />
          Portal de Ensino
        </p>
        <nav aria-label="Principal" className="space-y-4">
          {groups.map((group) => (
            <div key={group.moduleId}>
              <p className="mb-1 px-3 text-xs uppercase tracking-wide text-white/50">{group.label}</p>
              <ul className="space-y-1">
                {group.items.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      aria-current={pathname === item.href ? "page" : undefined}
                      className={`flex items-center gap-3 rounded-button px-3 py-2.5 text-sm hover:bg-white/10 ${
                        pathname === item.href ? "bg-secondary/20 font-semibold text-white" : "text-white/70"
                      }`}
                    >
                      {item.icon && <Icon name={item.icon} />}
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>
        <div className="mt-6 border-t border-white/5 pt-4 text-sm">
          <p className="truncate text-white/70">{state.user.displayName ?? state.user.email}</p>
          <Button type="button" variant="text" className="mt-1 px-0" onClick={() => void signOut()}>
            Sair
          </Button>
        </div>
      </aside>
      <main className="flex-1 p-6">{allowed ? children : <AccessDenied />}</main>
    </div>
  );
}
