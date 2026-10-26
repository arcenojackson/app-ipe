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

## Biblioteca e curadoria

A biblioteca é uma lista de arquivos e links **sem pastas**, organizada por tags.

- Rotas: `/ensino/biblioteca` (só leitura: itens publicados, com filtros e busca),
  `/ensino/revisao` (Fila de Revisão: tudo o que é envio e revisão) e
  `/ensino/notificacoes`. `?item={id}` abre a janela do item em qualquer tela.
- Tags (coleção `teaching_tags`, editada à mão no banco): três tipos — **tipo**
  (`type`), **assunto** (`subject`) e **faixa etária** (`age`). Todo envio e reenvio
  exige pelo menos uma tag de cada tipo. Cada documento é
  `{kind, name, order, active}`; `active: false` esconde a tag dos filtros sem
  quebrar os arquivos que a usam. A semente inicial está em
  `functions/src/teaching/tagSeed.ts` (`npm --prefix functions run seed-tags:dry`
  e `seed-tags`; só cria as que não existem).
- Biblioteca: consulta só `status == "published"`, ordenada por `publishedAt` (gravado
  pela Cloud Function ao publicar), com paginação por cursor. O servidor aplica um
  filtro principal (busca por prefixo em `searchTokens`, senão assunto, tipo ou faixa)
  e o cliente reaplica todos (dentro de um tipo de tag vale "ou"; entre tipos, "e").
  Índices em `firestore.indexes.json`.
- Fila de Revisão: professor vê só os próprios envios; curador também vê o que
  aguarda revisão e os pedidos de exclusão. Aprovado sai da Fila.
- Visualização: PDF, imagens e DOCX são desenhados no navegador (`pdfjs-dist`,
  `docx-preview`), lendo os bytes pelo Storage autenticado — sem URL pública.
  Isso exige CORS no bucket (`storage-cors.json`). Outros tipos mostram nome,
  tipo, tamanho e Baixar. Links abrem em nova aba.
- Código em `src/modules/teaching/library/`: lógica pura (`libraryQuery`,
  `searchTokens`, `tags`, `reviewQueue`, `permissions`, `status`, `files`,
  `payloads`, `convert`), camada de dados (`repository`, `mutations`,
  `notifications`, `uploadFlow`) e telas em `ui/`.
- As permissões reais estão nas regras do Firestore/Storage e nas Cloud Functions
  (`functions/src/teaching/library/`); a interface só esconde o que o papel não pode.
- Regras do produto: todo envio é revisado e precisa de 2 aprovações de curadores
  diferentes do autor; devolver é 1 curador; rejeitar e apagar exigem 2 curadores
  (e qualquer curador pode recusar um pedido de exclusão). Curadores podem corrigir
  tags durante a revisão (sem zerar aprovações; o autor é avisado).
- O portal precisa de pelo menos 3 curadores para aprovar envios de curadores e
  exclusões (a tela avisa).
- Limpeza da biblioteca antiga (uma vez, com autorização): `npm --prefix functions run
  purge-library:dry` conta o que seria apagado; `purge-library` apaga itens, votos,
  notificações e arquivos (mantém `teaching_log`, `teaching_tags` e usuários).

## Acesso

- `none` não entra; `teacher` lê a biblioteca e usa o fórum; `curator` também aprova;
  `admin` (campo `is_admin`) tem acesso total e é quem gerencia o grupo.
- Papéis vêm de custom claims (`teaching_role`, `admin`), copiadas de `users/{uid}`
  pela Cloud Function `syncTeachingClaimsOnUserWrite`.
- Limite conhecido: quem perde o papel pode manter acesso ao Storage por até 1 hora
  se já estiver com a sessão aberta (o token só renova então).
- Professor cuja conta do app usa apenas Sign in with Apple ainda não consegue entrar
  no portal: a Apple na web não está configurada (há suporte a e-mail/senha e Google).
