# Portal de Ensino IPE — Etapas 2 e 3: Biblioteca e Curadoria — Design

Data: 2026-10-15 · Branch: `teaching-library` · Status: rascunho para revisão
Complementa: `2026-10-12-teaching-portal-design.md` (spec geral). Onde houver conflito, **este documento vale** para biblioteca e curadoria.

## 1. Objetivo

Uma biblioteca de materiais para os professores da IPE, no estilo **Google Drive** (pastas dentro de pastas, arquivos e links), com **curadoria rigorosa**: nenhum material aparece para os professores sem a aprovação de pelo menos 2 curadores, e nada é apagado sem a aprovação de pelo menos 2 curadores. O objetivo é que todos estejam "na mesma página" teologicamente (teologia reformada da IPB).

As antigas etapas 2 (biblioteca) e 3 (curadoria) viram **uma entrega só**, por decisão do produto. A faixa etária e o tema deixam de ser campos de filtro: são **pastas**.

## 2. Decisões do produto

| Tema | Decisão |
|---|---|
| Modelo | Árvore de pastas estilo Drive. Itens: pasta, documento (arquivo), link (bibliografia). |
| Quem gerencia pastas | Somente curador (1 curador basta para criar, renomear e mover). |
| Quem envia | Professor e curador. **Todo envio é revisado**, nenhum nasce publicado. |
| Publicar | 2 aprovações de curadores **distintos entre si e diferentes do autor**. |
| Devolver com comentário | 1 curador basta. Zera as aprovações; o autor corrige e reenvia. |
| Rejeitar um envio novo | 2 curadores. O item e o arquivo são apagados. |
| Apagar documento publicado | Um curador pede; **2 outros** aprovam. Qualquer curador pode **Recusar** (encerra o pedido). Quem pediu pode cancelar. |
| Apagar pasta vazia (sem nenhum documento ou link em qualquer nível) | 1 curador, direto. |
| Apagar pasta com documentos dentro | Mesmo pedido de exclusão: 2 outros curadores. Leva tudo que está dentro. |
| Renomear e mover documento publicado | 1 curador, direto. |
| Quem conta como curador | Apenas quem tem `teaching_role = curator`. **Admin sem esse papel não vota nem apaga**, mas lê tudo. |
| Quem apaga | Ninguém apaga pelo navegador: toda exclusão é executada por Cloud Function. |
| Visibilidade | Professor vê pastas, itens publicados e os próprios envios (em revisão ou devolvidos). Curador e admin veem tudo. |
| Substituir arquivo publicado | Fora do escopo: envia-se um item novo e pede-se a exclusão do antigo. |

## 3. Arquitetura (abordagem aprovada)

Firestore + Cloud Functions como "juiz". O navegador e o app **não escrevem `status` nem contagens**: uma Function conta os votos e faz as transições. As regras novas valem só para coleções novas; **nenhuma regra existente é alterada**.

## 4. Modelo de dados

### 4.1 `teaching_items/{itemId}`
| Campo | Tipo | Notas |
|---|---|---|
| `type` | `folder` \| `file` \| `link` | |
| `name` | string, 1–120 | nome exibido |
| `parentId` | string \| null | `null` = raiz; precisa apontar para uma pasta |
| `authorId` | uid | quem criou |
| `status` | string | pasta: `active`. Documento/link: `in_review`, `returned` ou `published` (rejeição e exclusão apagam o item) |
| `version` | inteiro ≥ 1 | sobe a cada reenvio após devolução |
| `fileName`, `contentType`, `size`, `storagePath` | | só `file` |
| `url`, `description` | | só `link` (`url` deve ser `http` ou `https`) |
| `returnComment`, `returnedBy` | | preenchidos ao devolver |
| `deleteRequest` | map \| null | `{id, requestedBy, requestedAt, reason}` |
| `deleteRequested` | boolean | espelho de `deleteRequest != null`, para consultas |
| `createdAt`, `updatedAt` | timestamp | |

Storage: `teaching/materials/{itemId}/v{versão}-{nome}`. O caminho **não** contém a pasta, então mover e renomear não mexem no Storage. Profundidade máxima da árvore: 8 níveis.

### 4.2 `teaching_items/{itemId}/votes/{voteId}` (imutável)
`voterId`, `action` (`approve` \| `reject` \| `return` \| `delete_approve` \| `delete_refuse`), `version` (votos de publicação) ou `requestId` (votos de exclusão), `comment` (obrigatório em `return`, `reject` e `delete_refuse`), `createdAt`.

### 4.3 `teaching_notifications/{id}`
`toUid`, `type`, `itemId`, `title`, `body`, `createdAt`, `readAt`. Só Functions criam; o dono lê e marca `readAt`.

### 4.4 `teaching_log/{id}`
Registro append-only escrito só por Functions: `action`, `itemId`, `itemName`, `actors`, `at`. Serve para saber quem apagou o quê.

## 5. Máquina de estados (Cloud Functions)

Uma função **pura** `decide(item, votes, validCuratorIds)` devolve a transição; os gatilhos aplicam dentro de **transação** (se o estado já mudou, ignoram), então votos simultâneos não duplicam nada.

**Eleitor válido (publicação):** tem hoje `teaching_role = curator` no **Auth** (relido na hora de contar), `uid ≠ authorId`, e o voto é da versão atual. Vale o **último voto** de cada curador.
- `return` de qualquer eleitor válido → `returned` (comentário guardado). Aprovações da versão ficam como histórico e deixam de contar.
- 2 `approve` distintos → `published`.
- 2 `reject` distintos → o item e todos os seus objetos no Storage são apagados; o autor é avisado com os comentários.
- Reenvio do autor (`returned` → `in_review`, `version + 1`) → a Function apaga do Storage o arquivo da versão anterior e avisa os curadores.

**Exclusão:** eleitor válido = curador atual, `uid ≠ requestedBy`, voto do `requestId` atual.
- 1 `delete_refuse` → o pedido é encerrado (`deleteRequest = null`); quem pediu é avisado.
- 2 `delete_approve` distintos → a Function apaga o item e seus arquivos. Em pasta, apaga a subárvore inteira (em lotes).
- Pedido sobre pasta **sem nenhum documento ou link** em qualquer nível é executado na hora, sem votos.
- Quem pediu pode cancelar.

**Invariantes reativas:** ao mudar `parentId`, a Function recusa (desfazendo o movimento) se criar ciclo, ultrapassar 8 níveis ou apontar para algo que não é pasta. Todas as ações relevantes gravam em `teaching_log`.

Os gatilhos usam retentativa (`failurePolicy`), e as transições são idempotentes.

## 6. Segurança

### 6.1 Regras do Firestore (apenas coleções novas)
- **Leitura de item:** curador e admin leem tudo. Professor lê `status in ['active','published']` **ou** `authorId == uid`. Consultas precisam trazer os filtros que provam a regra (detalhado na seção 7).
- **Criar item:** professor, curador ou admin com acesso à área; `status == 'in_review'` (documento/link) ou `'active'` (pasta, só curador); `authorId == uid`; `version == 1`; pai existente e do tipo pasta.
- **Atualizar item (cliente):** só estes casos, com `affectedKeys` restritos:
  - curador: `name`, `parentId`, `updatedAt`;
  - curador: abrir pedido de exclusão (`deleteRequest`, `deleteRequested`), só em item publicado ou pasta, com `requestedBy == uid`;
  - quem pediu: cancelar o próprio pedido;
  - autor, item `returned`: reenviar (`version + 1`, `status = in_review`, campos do arquivo/link e `name`).
- **`status`, contagens e remoções são exclusivos das Functions** (Admin SDK). **Nenhuma exclusão pelo cliente.**
- **Votos:** `create` por curador (claim `teaching_role == curator`), `voterId == uid`, em votos de publicação `uid ≠ authorId`, em votos de exclusão `uid ≠ requestedBy` (quem pediu; o autor do item **pode** aprovar a exclusão), item no estado certo e versão/`requestId` correspondentes; imutáveis depois.
- **Notificações:** só o dono lê e atualiza `readAt`.

### 6.2 Regras do Storage (substituem as de `teaching/materials`)
- **Ler:** acesso à área **e** item `published`, ou autor, ou curador/admin (consulta ao Firestore pela regra). Arquivo em revisão não é baixável por outros professores.
- **Criar:** professor ou superior, tamanho até 100 MB, tipos permitidos como hoje (PDF, Office, imagens), objeto novo (nunca sobrescreve).
- **Sobrescrever e apagar:** negados no cliente. A Function (Admin SDK) apaga.

### 6.3 Risco aceito (registrado)
A regra dos 2 curadores vale tanto quanto a integridade do papel `curator`. Como `teaching_role` fica em `users` (decisão do produto, sem alterar regras existentes) e o próprio usuário consegue gravar o próprio documento, um usuário com conhecimento técnico poderia se promover a curador, e a Function, que lê o papel, o trataria como tal. O mesmo vale para `is_admin`. Se um dia for necessário fechar isso, o caminho é mover os papéis para uma coleção gravável só por admin e fazer a Function derivar as claims dela.

## 7. Telas do portal

Rotas sob `/ensino/biblioteca` (pasta atual em parâmetro de busca, `?pasta=ID`).

- **Biblioteca (estilo Drive):** migalhas de pão, lista e grade, busca por nome, botões "Nova pasta" (curador), "Enviar arquivos" e "Adicionar link", arrastar e soltar com vários arquivos e barra de progresso, menu por item (Abrir/Baixar, Renomear e Mover para curador, Solicitar exclusão para curador) e selos: `Em revisão 1/2`, `Devolvido`, `Exclusão solicitada`.
- **Navegação:** consulta por pasta com escuta em tempo real. Professor faz duas consultas (publicado/ativo da pasta; seus envios na pasta) e junta no cliente; curador faz uma. A busca por nome carrega uma vez todos os itens visíveis e filtra no cliente (escala de igreja). Índices compostos em `firestore.indexes.json`.
- **Detalhe do item:** PDF e imagens abrem na página; Office só baixa; links abrem em nova aba. Histórico de votos com comentários. Ações conforme o papel: Aprovar, Devolver (comentário obrigatório), Rejeitar (motivo obrigatório), Aprovar ou Recusar exclusão, Cancelar pedido, Reenviar.
- **Fila de revisão (curadores):** envios aguardando (que você não escreveu e ainda não votou) e pedidos de exclusão, com a contagem de aprovações.
- **Notificações:** sino com contador e página de caixa de entrada. Aviso quando há menos de 3 curadores.
- Identidade visual, tokens e componentes: os da etapa 1. Módulo `src/modules/teaching/` ganha `library/` (dados e páginas) e itens no menu.

## 8. Notificações

- **Curadores** (exceto o autor): novo envio em revisão, reenvio e pedido de exclusão.
- **Autor:** publicado, devolvido (com o comentário) e rejeitado.
- **Quem pediu a exclusão:** aprovada/executada, recusada.
- Destino: caixa do portal (`teaching_notifications`) e **push no app** quando o usuário tem `fcmToken`, respeitando `disabled_notifications` (nova chave `teaching_review`). O push leva a URL do item no portal.

## 9. App Flutter

Mudança mínima: ao tocar numa notificação de curadoria, abrir o portal no item (`url_launcher`). A biblioteca em si não é reimplementada no app.

## 10. Erros e casos de borda

- **Menos de 3 curadores:** envio de curador nunca alcança 2 aprovações de outros; envio de professor precisa de pelo menos 2 curadores. O portal avisa; operacionalmente é preciso promover mais curadores.
- **Upload sem item (falha no meio):** objetos órfãos ficam inacessíveis (a leitura exige o item). Limpeza programada fica como melhoria futura.
- **Curador rebaixado durante a votação:** o voto é descartado na contagem (papel relido no Auth).
- **Nomes duplicados na mesma pasta:** permitidos (como no Drive).
- **Autor deixa de existir:** o item continua; notificações ao autor são ignoradas.

## 11. Testes

- **Regras (emulador do Firebase, Firestore e Storage juntos):** visibilidade por papel, criação, atualizações permitidas e negadas, votos (autor não vota, não curador não vota, versão errada), leitura do Storage por status, nenhuma exclusão pelo cliente, consultas do professor aceitas.
- **Functions:** a função pura `decide` com todas as combinações (devolução, empate, voto trocado, curador rebaixado, aprovação do autor ignorada, exclusão e recusa); gatilhos com Firestore fake e transação; ciclo e profundidade; cascata de pasta; notificações.
- **Portal:** lógica pura (árvore, selos, permissões de ações) e componentes principais com a camada de dados simulada.
- **Verificação final com o usuário:** com 3 ou mais curadores reais promovidos.

## 12. Entrega em dois planos

- **Plano A (base):** coleções e regras do Firestore e do Storage, índices, Functions (máquina de estados, limpeza, validações, notificações, log), testes.
- **Plano B (telas):** camada de dados do portal, biblioteca estilo Drive, envio, revisão, ferramentas de curador, fila, notificações, ajuste do app, deploy e verificação.

## 13. Fora de escopo

Substituir arquivo publicado, histórico de versões navegável, lixeira, compartilhamento por link, comentários dentro do documento, busca no conteúdo dos arquivos, fórum (etapa 4), limpeza automática de órfãos, e-mail como canal de notificação.

## 14. Ajustes feitos na implementação do Plano A (valem para o Plano B)

- **Campo `updatedBy`:** todo `create`/`update` do cliente grava `updatedBy == uid` e `updatedAt == request.time`. É assim que a Function sabe quem moveu ou pediu algo e avisa a pessoa certa.
- **Marcador `deleting` (`"reject"` | `"execute"`):** escrito **só pela Function**, dentro da transação do voto, quando a rejeição ou a exclusão é decidida. Depois dele a decisão é final: votos posteriores (recusa, devolução, aprovação) não a desfazem, e a retentativa só conclui a remoção. O cliente não escreve esse campo.
- **Storage guarda só o objeto atual:** o cliente envia para `teaching/materials/{itemId}/...` com nome novo a cada versão (convenção `v{versão}-{nome}`). Ao reenviar, a Function apaga todos os objetos do item exceto o `storagePath` **atual do documento vivo**. As regras do Storage não validam o número da versão.
- **Reenvio limpa `returnComment` e `returnedBy`:** a Function zera esses campos quando o item volta para `in_review`.
- **`deleteRequest.id` deve ser um uuid gerado pelo cliente.** Reutilizar um id faria votos antigos valerem no pedido novo e colidiria com o id determinístico das notificações.
- **Pasta sem documentos:** a exclusão imediata revalida, no Auth, que quem pediu ainda é curador; se não for, o pedido é cancelado.
- **Item `returned` sem reenvio** não pode ser apagado por ninguém (o pedido de exclusão só vale para `active`/`published`, e rejeitar só vale para `in_review`). Decisão de produto pendente.
- **Consultas do professor:** sem índices compostos. Por pasta, 3 consultas de igualdade juntadas no cliente: `parentId == X` com `status == "published"`, com `status == "active"` e com `authorId == uid`; ordenação por nome no cliente. Consulta sem filtro de status/autor é negada pelas regras.
- **Link de notificação:** o push abre `{portal}/ensino/biblioteca?item={id}` (e não `?pasta=`). O portal deve abrir o detalhe do item por esse parâmetro.
- **Operação:** Cloud Functions primeiro, depois as regras; o Storage com leitura cruzada ao Firestore pode pedir permissão do agente de serviço no deploy; o bucket padrão está fixo em `app-ipe.firebasestorage.app`.

## 15. Pendências para os planos

- Confirmar no ambiente se a regra de leitura do Storage consultando o Firestore funciona no emulador (Firestore e Storage juntos).
- Definir os textos exatos (pt-BR) das notificações.
- Decidir o tamanho do lote da exclusão em cascata de pastas grandes.
