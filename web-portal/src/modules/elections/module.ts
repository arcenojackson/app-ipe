import type {PortalModule} from "@/core/modules/types";

// Qualquer pessoa logada entra na rota; quem não é diretor da eleição vê
// "Acesso restrito" (e o servidor e as regras recusam de qualquer forma).
export const electionsModule: PortalModule = {
  id: "elections",
  label: "Eleições",
  basePath: "/eleicoes",
  access: "authenticated",
  navItems: [],
};
