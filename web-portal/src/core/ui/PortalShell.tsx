"use client";

import Link from "next/link";
import {usePathname, useRouter} from "next/navigation";
import {useEffect, useRef, useState, type ReactNode} from "react";
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
  const [menuOpen, setMenuOpen] = useState(false);
  const burgerRef = useRef<HTMLButtonElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);

  // Menu móvel: Esc fecha e o foco acompanha (vai para o X ao abrir e volta
  // para o ☰ ao fechar).
  useEffect(() => {
    if (!menuOpen) return;
    const burger = burgerRef.current;
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMenuOpen(false);
    };
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("keydown", onKey);
      burger?.focus();
    };
  }, [menuOpen]);

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
      <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-white/5 bg-surface px-4 py-3 md:hidden">
        <button
          ref={burgerRef}
          type="button"
          aria-label="Abrir menu"
          aria-expanded={menuOpen}
          aria-controls="portal-menu"
          onClick={() => setMenuOpen(true)}
          className="grid h-10 w-10 place-items-center rounded-button bg-surface-elevated"
        >
          <Icon name="list" />
        </button>
        <Brand />
      </header>
      {menuOpen && (
        <button
          type="button"
          tabIndex={-1}
          aria-label="Fechar menu"
          onClick={() => setMenuOpen(false)}
          className="fixed inset-0 z-40 bg-black/55 md:hidden"
        />
      )}
      <aside
        id="portal-menu"
        className={`fixed inset-y-0 left-0 z-50 w-[280px] max-w-[85%] overflow-y-auto border-r border-white/5 bg-surface p-4 shadow-2xl transition-[transform,visibility] duration-200 md:static md:z-auto md:min-h-screen md:w-64 md:max-w-none md:translate-x-0 md:overflow-visible md:shadow-none md:visible ${
          menuOpen ? "translate-x-0" : "invisible -translate-x-full"
        }`}
      >
        <div className="mb-5 flex items-center justify-between">
          <Brand />
          <button
            ref={closeRef}
            type="button"
            aria-label="Fechar menu"
            onClick={() => setMenuOpen(false)}
            className="grid h-10 w-10 place-items-center rounded-button text-white/60 hover:bg-white/10 md:hidden"
          >
            ✕
          </button>
        </div>
        <nav aria-label="Principal" className="space-y-4">
          {groups.map((group) => (
            <div key={group.moduleId}>
              <p className="mb-1 px-3 text-xs uppercase tracking-wide text-white/50">{group.label}</p>
              <ul className="space-y-1">
                {group.items.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      onClick={() => setMenuOpen(false)}
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

function Brand() {
  return (
    <p className="flex items-center gap-2.5 px-2 text-base font-bold">
      <span aria-hidden className="h-7 w-7 rounded-[9px] bg-gradient-to-br from-primary to-secondary" />
      Portal de Ensino
    </p>
  );
}
