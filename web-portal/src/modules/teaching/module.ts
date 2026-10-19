import type {PortalModule} from "@/core/modules/types";

export const teachingModule: PortalModule = {
  id: "teaching",
  label: "Ensino",
  basePath: "/ensino",
  access: "teacher",
  navItems: [
    {label: "Início", href: "/ensino", access: "teacher"},
    {label: "Biblioteca", href: "/ensino/biblioteca", access: "teacher"},
    {label: "Grupo de professores", href: "/ensino/admin", access: "admin"},
  ],
};
