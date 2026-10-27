import type {PortalModule} from "@/core/modules/types";

export const teachingModule: PortalModule = {
  id: "teaching",
  label: "Ensino",
  basePath: "/ensino",
  access: "teacher",
  navItems: [
    {label: "Biblioteca", href: "/ensino", access: "teacher", icon: "library"},
    {label: "Fórum", href: "/ensino/forum", access: "teacher", icon: "forum"},
    {label: "Plano pedagógico", href: "/ensino/plano", access: "teacher", icon: "plan"},
    {label: "Fila de revisão", href: "/ensino/revisao", access: "teacher", icon: "review"},
    {label: "Notificações", href: "/ensino/notificacoes", access: "teacher", icon: "bell"},
    {label: "Grupo de professores", href: "/ensino/admin", access: "teachingManager", icon: "admin"},
  ],
};
