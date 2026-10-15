import type {AccessRequirement} from "@/core/auth/access";

export interface NavItem {
  label: string;
  href: string;
  access: AccessRequirement;
}

/**
 * Um módulo do portal (ensino, e no futuro membros, eventos etc.).
 * Para adicionar um módulo: criar src/modules/<id>/module.ts com este tipo,
 * registrá-lo em registry.ts e criar as rotas finas em src/app/(portal)/.
 */
export interface PortalModule {
  id: string;
  label: string;
  basePath: string;
  access: AccessRequirement;
  navItems: NavItem[];
}

export interface NavGroup {
  moduleId: string;
  label: string;
  items: NavItem[];
}
