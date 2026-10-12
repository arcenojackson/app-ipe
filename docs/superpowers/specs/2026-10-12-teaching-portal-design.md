# Portal de Ensino IPE — Design

Data: 2026-10-12 · Branch: `worktree-teaching-portal` · Status: rascunho para revisão

## 1. Objetivo

Criar um lugar central para o programa de ensino teológico da IPE: currículo, materiais e bibliografia para professores de todas as faixas etárias (crianças, adolescentes, jovens e adultos), com curadoria alinhada à teologia reformada que a IPB subscreve, e um fórum para dúvidas e conversas entre os professores.

A parte principal é a **web**. O app mobile complementa, principalmente com o fórum.

## 2. Decisões já tomadas

| Tema | Decisão |
|---|---|
| Público | Somente a IPE. Sem multi-tenant. |
| Quem acessa | Só o grupo de professores. Eles leem todo o material e criam e respondem tópicos no fórum. Quem não é do grupo não vê nada da área. |
| Conteúdo | Arquivos enviados (PDF, Office, imagens). Bibliografia também pode ser link externo. Nada de editor de texto rico no escopo. |
| Login | A mesma conta do app (Firebase Auth). Sem fluxo de cadastro separado. |
| Plataforma | Portal web **Next.js na Vercel**, no mesmo projeto Firebase do app. |
| Backend | O mesmo Firebase: Auth, Firestore, Storage e Functions. Sem segundo backend. |
| Fórum | Existe no app (dentro da área de ensino) **e** na web, sobre as mesmas coleções. |

## 3. Requisitos transversais do portal

### 3.1 Identidade visual idêntica à do app
O portal usa a mesma identidade do app (`lib/src/shared/theme/app_theme.dart`):

- Tema escuro. Fundo `#0B0F19`, superfície `#111828`, superfície elevada `#1B2435`.
- Cor primária `#2F4F2F` (verde oliva escuro), secundária `#6B8E23`, erro `#FF5470`, texto branco.
- Cards com raio 18, diálogos e bottom sheets com raio 28, campos preenchidos com raio 18 e borda branca a 5%, borda de foco na cor primária.
- Botão principal preenchido com a cor primária, raio 18, texto 16 px peso 600.
- Estilo "vidro" (`glass_container.dart`): gradiente branco 12% → 4%, borda branca a 8%, blur 20, raio 24.
- Tipografia: a do sistema, sem fonte customizada (o app não embute fontes).

Esses valores viram **design tokens** em um único arquivo do portal (variáveis CSS e configuração do Tailwind). Nenhum componente usa cor ou raio fixo no código.
Na etapa 1, os tokens são conferidos contra o `app_theme.dart` e qualquer divergência é corrigida no portal, porque o app é a referência.

### 3.2 Preparado para novas telas e features
O portal é a base de uma web mais ampla, e a migração gradual de outros módulos do app é possível no futuro, mas **não faz parte desta feature**. Para não bloquear isso:

- Estrutura por módulo: `src/modules/teaching/*` (e, depois, `members`, `events` etc.). Cada módulo tem suas rotas, componentes, acesso a dados e tipos.
- Casca compartilhada: layout, menu lateral, autenticação, tokens e componentes de UI ficam fora dos módulos. Um módulo novo entra registrando suas rotas e seu item de menu, sem mexer nos outros.
- Controle de acesso por módulo: um guarda de rota que lê as claims do token, de modo que cada módulo declara quem pode entrar.
- Camada de dados tipada, uma por módulo, para que regras e telas não falem com o Firestore diretamente.
- Raiz do portal: `web-portal/`, dentro deste repositório, compartilhando `firestore.rules`, `storage.rules`, `functions/` e `firebase.json`.

## 4. Arquitetura

- **Portal web (`web-portal/`)**: biblioteca, curadoria, administração do grupo e fórum.
- **App Flutter**: área de ensino com o fórum nativo e push. A biblioteca não é reimplementada, e um botão abre o portal no navegador.
- **Firebase compartilhado**: Auth, Firestore (metadados e fórum), Storage (arquivos), Functions (claims e notificações).

## 5. Papéis e acesso

- `users/{uid}.teaching_role`: `none` | `teacher` | `curator`. O curador é um professor com poder extra.
- O `is_admin` existente continua sendo o administrador. Só o admin atribui e retira papéis.
- Uma Cloud Function copia `teaching_role` (e `is_admin`) para custom claims no token ao alterar o papel. As regras leem a claim, sem consultar outro documento.
- Quem tem `none` não acessa a área, nem no app nem na web.

## 6. Dados

### 6.1 `teaching_materials/{id}`
Título, descrição, faixa etária (`kids` | `teens` | `youth` | `adults`), tema, tipo (aula, plano, bibliografia), status (`draft` | `in_review` | `published`), `storagePath` (ou `externalUrl` para bibliografia), nome, tipo e tamanho do arquivo, autor, revisor, comentário de devolução, datas.

- Professor: lê o que está `published`, e cria e edita os próprios rascunhos.
- Curador e admin: leem tudo, aprovam, devolvem e publicam. Quem escreve um material só o publica sozinho se for curador.

### 6.2 Storage
Arquivos em `teaching/materials/{id}/{nome}`. Leitura exige a claim de professor ou superior. Escrita exige professor, com limite de tamanho e lista de tipos permitidos (PDF, Office, imagens).
Um material só vai para `in_review` depois de o arquivo estar no Storage.

### 6.3 Fórum
`forum_threads/{id}` com subcoleção `posts`, no padrão do chat atual. Categorias iniciais: uma por faixa etária e uma geral. Só o grupo de professores lê, abre tópicos e responde. O autor edita e apaga o que escreveu, e curador e admin moderam.

## 7. Telas

**Portal web**
- Login com a conta do app. Quem não tem papel vê "acesso restrito ao grupo de professores".
- Biblioteca com filtros (faixa etária, tema, tipo) e busca por título e descrição. Página do material com PDF inline e botão de baixar.
- Meus materiais: rascunhos, status e envio de arquivo com barra de progresso.
- Fila de curadoria (curador e admin): aprovar, devolver com comentário, publicar.
- Administração do grupo (admin): dar e retirar o papel de professor ou curador.
- Fórum: tópicos por categoria, página do tópico com respostas em tempo real, criação de tópico.

**App Flutter**
- Item de acesso à área de ensino, visível só para quem tem papel.
- Dentro da área de ensino: fórum nativo completo e um botão que abre a biblioteca no portal.

## 8. Notificações (Cloud Functions)

- Resposta em tópico que o usuário abriu, ou menção.
- Material enviado para revisão (avisa os curadores).
- Material aprovado ou devolvido (avisa o autor).

## 9. Ordem de construção

Cada etapa tem sua própria spec e seu próprio plano.

1. **Fundação**: projeto Next.js na Vercel com a casca modular e os tokens visuais, login compartilhado, `teaching_role` e a Function de claims, regras do Firestore e do Storage, administração do grupo.
2. **Biblioteca**: upload, metadados, listagem, filtros e visualização.
3. **Curadoria**: fluxo de status, fila de revisão, bibliografia com link externo, notificações de revisão.
4. **Fórum**: no app e na web, sobre as mesmas coleções.

## 10. Custos do Storage (estimativa, a confirmar no console)

- Bucket antigo (`*.appspot.com`): US$ 0,026/GB-mês após 5 GB grátis; download US$ 0,12/GB após 1 GB/dia grátis.
- Bucket novo (`*.firebasestorage.app`): preço da tabela do Google Cloud Storage, com cota grátis só em `us-central1`, `us-east1` e `us-west1`.
- Exemplo de 20 GB armazenados e 100 GB baixados por mês: cerca de US$ 9 no bucket antigo, menos de US$ 1 em bucket novo dentro da cota.
- Os valores do Google Cloud Storage vêm de fontes secundárias e devem ser conferidos antes de decidir a região.

## 11. Erros e testes

- Upload interrompido retoma, e o status só avança com o arquivo gravado.
- Testes principais: **regras de segurança no emulador do Firebase** (quem lê, escreve e publica), a Function de claims, e testes de interface nos fluxos principais.

## 12. Fora de escopo

Versionamento de arquivos, comentários dentro do material, busca no texto dos PDFs, anexos no fórum, e a migração de outros módulos do app para a web.

## 13. Pendências para o plano da etapa 1

- Confirmar no console qual bucket o projeto usa (antigo ou novo) e a região.
- Definir o domínio do portal.
- Conferir os tokens visuais do portal contra o `app_theme.dart` no início da implementação.
