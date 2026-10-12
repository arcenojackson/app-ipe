# Portal de Ensino IPE

Portal web (Next.js) da área de ensino da IPE. Usa o mesmo projeto Firebase
(`app-ipe`) e a mesma conta do app Flutter.

## Rodar localmente

1. `cp .env.example .env.local` e preencha com `firebase apps:sdkconfig WEB <APP_ID> --project app-ipe`.
2. `npm install`
3. `npm run dev` → http://localhost:3000

Scripts: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`.
O `build` precisa das variáveis `NEXT_PUBLIC_FIREBASE_*` definidas.

## Estrutura

- `src/core/` — casca compartilhada: Firebase, autenticação, acesso por claims,
  registro de módulos, componentes de UI.
- `src/modules/<módulo>/` — um módulo por área (hoje só `teaching`), com `module.ts`,
  `data/` e `pages/`.
- `src/app/` — rotas do Next.js; as de módulos são finas e só reexportam a página do módulo.
- `src/styles/tokens.css` — tokens visuais. A fonte de verdade é
  `lib/src/shared/theme/app_theme.dart`; `tokens.test.ts` falha se divergirem.

## Como adicionar um módulo

1. Criar `src/modules/<id>/module.ts` exportando um `PortalModule`
   (`basePath`, `access` e `navItems`).
2. Registrá-lo em `src/core/modules/registry.ts` (`portalModules`).
3. Criar as rotas finas em `src/app/(portal)/<basePath>/`.

Menu e guarda de acesso passam a valer sozinhos.

## Acesso

- `none` não entra; `teacher` lê a biblioteca e usa o fórum; `curator` também aprova;
  `admin` (campo `is_admin`) tem acesso total e é quem gerencia o grupo.
- Papéis vêm de custom claims (`teaching_role`, `admin`), copiadas de `users/{uid}`
  pela Cloud Function `syncTeachingClaimsOnUserWrite`.
- Limite conhecido: quem perde o papel pode manter acesso ao Storage por até 1 hora
  se já estiver com a sessão aberta (o token só renova então).
- Professor cuja conta do app usa apenas Sign in with Apple ainda não consegue entrar
  no portal: a Apple na web não está configurada (há suporte a e-mail/senha e Google).
