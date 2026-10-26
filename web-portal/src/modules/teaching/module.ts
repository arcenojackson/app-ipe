import type {PortalModule} from "@/core/modules/types";

export const teachingModule: PortalModule = {
  id: "teaching",
  label: "Ensino",
  basePath: "/ensino",
  access: "teacher",
  navItems: [
    {label: "Biblioteca", href: "/ensino", access: "teacher"},
    {label: "Plano pedagógico", href: "/ensino/plano", access: "teacher"},
    {label: "Fila de revisão", href: "/ensino/revisao", access: "teacher"},
    {label: "Notificações", href: "/ensino/notificacoes", access: "teacher"},
    {label: "Grupo de professores", href: "/ensino/admin", access: "admin"},
  ],
};
