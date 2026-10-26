import {hasAccess, type AccessClaims} from "@/core/auth/access";
import {electionsModule} from "@/modules/elections/module";
import {teachingModule} from "@/modules/teaching/module";
import type {NavGroup, PortalModule} from "./types";

export const portalModules: PortalModule[] = [teachingModule, electionsModule];

function isUnder(pathname: string, base: string): boolean {
  return pathname === base || pathname.startsWith(`${base}/`);
}

export function visibleNavGroups(
  modules: PortalModule[],
  claims: AccessClaims | null
): NavGroup[] {
  const groups: NavGroup[] = [];
  for (const mod of modules) {
    if (!hasAccess(claims, mod.access)) continue;
    const items = mod.navItems.filter((item) => hasAccess(claims, item.access));
    if (items.length > 0) {
      groups.push({moduleId: mod.id, label: mod.label, items});
    }
  }
  return groups;
}

export function isPathAllowed(
  modules: PortalModule[],
  pathname: string,
  claims: AccessClaims | null
): boolean {
  const mod = modules.find((m) => isUnder(pathname, m.basePath));
  if (!mod) return hasAccess(claims, "authenticated");
  if (!hasAccess(claims, mod.access)) return false;
  const item = mod.navItems
    .filter((i) => isUnder(pathname, i.href))
    .sort((a, b) => b.href.length - a.href.length)[0];
  return item ? hasAccess(claims, item.access) : true;
}

export function defaultLandingPath(
  modules: PortalModule[],
  claims: AccessClaims | null
): string | null {
  return visibleNavGroups(modules, claims)[0]?.items[0]?.href ?? null;
}
