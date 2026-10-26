# Portal de Ensino — Biblioteca por tags, Fila de Revisão e visualização rápida

Data: 2026-10-25. Continua o design `2026-10-15-teaching-library-curation-design.md` (curadoria) e o Plano B já mergeado (PR #4). Este documento **substitui** a parte de pastas daquele design e **mantém** as regras de curadoria.

## 1. Intenção e porquê

Os curadores da IPE já organizaram materiais de ensino no Google Drive (pastas como sermões, recursos pedagógicos, fichamentos e resumos, bibliografia, aulas, artigos). O objetivo final é levar esse acervo para o portal, com curadoria. A biblioteca atual do portal imita o Drive, com pastas e árvore. O stakeholder pediu algo diferente:

- A tela inicial mostra os **conteúdos diretamente**, como uma lista do Drive, sem navegar por pastas.
- A organização passa a ser por **tags**, não por pastas.
- Tudo o que é **envio e revisão** sai da biblioteca e vai para a **Fila de Revisão**.
- Qualquer arquivo pode ser **visto rapidamente** dentro do portal, em uma janela (modal).

O plano pedagógico anual (52 temas, hoje uma planilha criada para a UPA) será adotado por **todas** as sociedades e classes. É dele que saem as tags de assunto.

## 2. Objetivos, não-objetivos e anti-objetivos

**Objetivos**
1. Biblioteca sem pastas, **implementada do zero**: tabela de arquivos publicados, filtrada por tags e busca, **com paginação e consultas eficientes desde o início** (o acervo vai crescer).
2. Três tipos de tag (tipo, assunto, faixa etária), com pelo menos uma de cada tipo obrigatória em todo envio.
3. Tags guardadas em dados (coleção do Firestore), nunca no código.
4. Fila de Revisão como único lugar de envio, acompanhamento e revisão.
5. Janela de visualização acessível ao clicar em qualquer arquivo, em qualquer tela do portal.
6. Aceitar envio de qualquer tipo de arquivo.

**Não-objetivos (ficam para depois, projetos separados)**
- Transformar a planilha do plano pedagógico em uma tela do app, com edição.
- A Biblioteca no app Flutter (será só consulta, com download; sem a janela de visualização).
- Editar DOCX dentro da plataforma (por ora: só baixar e editar fora).
- Telas para criar/editar tags (por ora, só pelo banco, manualmente).
- Pré-visualização de planilhas e apresentações (melhoria futura).
- O fórum.

**Anti-objetivos (seria fracasso mesmo que "funcione")**
- Expor arquivos a quem não é do grupo de professores (por exemplo URL pública só para o visualizador funcionar).
- Apertar regras do Firestore existentes (diretriz permanente do usuário: papéis são gerenciados pelo app; só mudanças **aditivas** ou que **afrouxam** o necessário).
- Tags escritas no código.

## 3. Estado atual (o que já existe)

Portal Next.js em `web-portal/` (Vercel, https://ipe-ensino.vercel.app), mesmo projeto Firebase do app. Biblioteca atual (módulo `web-portal/src/modules/teaching/library/`): itens em `teaching_items` (tipo folder|file|link, `parentId`, status active|in_review|returned|published, `version`, votos em subcoleção `votes`), fila de revisão em `/ensino/revisao`, notificações em `/ensino/notificacoes`, Cloud Functions que decidem as transições (2 aprovações de curadores para publicar, devolução por 1 curador, rejeição por 2, exclusão com 2 outros curadores e veto de 1), regras do Firestore e do Storage já em produção. A tela de biblioteca navega por pastas (`?pasta=`), com breadcrumbs, "Nova pasta", "Gerenciar pasta", mover.

## 4. Decisões do usuário (como foram tomadas)

### 4.1 Biblioteca (tela inicial)
- Layout "A": **tabela estilo Drive** com filtros no topo (Tipo, Assunto, Faixa) e busca por texto; chips dos filtros ativos.
- Colunas: nome, tags, autor, data (e tamanho para arquivos).
- **Somente arquivos e links já publicados** aparecem, para todos, **inclusive curadores**. Itens em revisão ou devolvidos **não** aparecem aqui.
- O nome do **autor** do arquivo fica visível na Biblioteca.
- Sem pastas: some a navegação por pasta, breadcrumbs, criar/mover/gerenciar pasta.
- **Links**: continuam existindo, com as mesmas tags e a mesma revisão; ao clicar, abrem em **nova aba** (não abrem a janela de visualização).

### 4.2 Tags
- Três tipos de tag:
  1. **Tipo/categoria**: o que o material é. Valores iniciais (as pastas do Drive): Sermões, Recursos pedagógicos, Fichamentos e resumos, Bibliografia, Aulas, Artigos.
  2. **Assunto**: o tema. Valores iniciais (25, agrupados a partir dos 52 temas da planilha "Planejamento_Pedagógico_UPA"; o número entre parênteses é a aula de origem):
     1. Identidade cristã e evangelho (1)
     2. Bíblia: autoridade e inspiração (2)
     3. Interpretação bíblica (3)
     4. História da redenção (4)
     5. Cosmovisão e síntese da fé reformada (5, 51, 52)
     6. Reforma e os cinco Solas (6)
     7. Existência e revelação de Deus (7)
     8. Atributos de Deus e adoração (8, 12)
     9. Trindade (9)
     10. Soberania e providência (10)
     11. O problema do mal e o sofrimento (11)
     12. Criação e imagem de Deus (13, 14)
     13. Queda, pecado e idolatria (15, 16, 17)
     14. Pessoa de Cristo (18, 19, 23)
     15. Obra de Cristo (20, 21, 22, 24)
     16. Salvação, eleição e graça (25, 26, 27)
     17. Justificação, adoção e santificação (28 a 31)
     18. Espírito Santo e seus dons (32 a 35)
     19. Crescimento cristão e meios de graça (36, 39)
     20. Igreja e missão (37, 38, 42)
     21. Sacramentos (40, 41)
     22. Ética, lei de Deus e consciência (43)
     23. Relacionamentos, sexualidade e redes sociais (44, 45)
     24. Vocação, trabalho e dinheiro (46, 47)
     25. Escatologia e vida futura (48, 49, 50)
  3. **Faixa etária** (lista fixa, informada pelo usuário): **UCP** (infantil), **UPA** (adolescentes), **UMP** (jovens), **ADULTOS**, **CASAIS**, **SAF** (irmãs), **HOMENS**. O usuário pediu que as tags de faixa mostrem **apenas siglas**; ADULTOS, CASAIS e HOMENS são palavras, não siglas, e foram mantidas como ditas (a confirmar, ver seção 7).
- Um arquivo pode ter **várias** tags de cada tipo (exemplo do usuário: ARTIGOS | OS CINCO SOLAS | UMP; ADULTOS).
- **Todo envio** (de professor ou curador) exige **pelo menos uma tag de cada um dos três tipos**.
- As tags vivem em uma **coleção do Firestore** (nome a definir pelo construtor), lida pelo portal e, depois, pelo app. **Criar e editar tags é manual, direto no banco, por enquanto.** O sistema não tem tela para isso.
- Os 25 assuntos e as faixas são só o ponto de partida; o usuário espera acrescentar e editar depois, sem mudar código.
- Curadores podem **corrigir e acrescentar tags no momento da revisão** (ver 4.3).

### 4.3 Fila de Revisão (único lugar de envio e revisão)
- **Professor**: vê **somente os arquivos que ele mesmo enviou** (em revisão, devolvidos). É aqui que envia arquivos novos, acompanha o andamento e reenvia os devolvidos com comentário.
- **Curador**: vê os **seus** arquivos **e** os arquivos de outros que aguardam revisão. Vota (aprovar/rejeitar/devolver) e comenta aqui, e pode corrigir ou acrescentar tags durante a revisão.
- Ao ser **aprovado e publicado**, o arquivo **sai** da Fila de Revisão e passa a existir só na Biblioteca (com o nome do autor).
- As regras de curadoria **não mudam**: 2 aprovações de curadores distintos e diferentes do autor para publicar; devolução por 1 curador (zera aprovações); rejeição de envio novo por 2; exclusão de arquivo publicado por pedido + 2 outros curadores, com veto de 1.

### 4.4 Visualização rápida (somente web)
- Uma **janela (modal)** que abre ao **clicar em qualquer arquivo, em qualquer tela** (Biblioteca, Fila de Revisão, link de notificação), para arquivos publicados e, principalmente, os **em revisão**.
- Apenas visualização; o **download** continua disponível (e é o único jeito de editar DOCX).
- **Versão 1**: PDF, imagens e DOCX exibidos no navegador. Preferência registrada pelo usuário e confirmada: renderizar **no próprio navegador**, com bibliotecas gratuitas, **sem** enviar o arquivo a serviços externos nem criar URL pública (pesquisa feita: as bibliotecas "tudo em um" tipo `react-doc-viewer` usam o visualizador online da Microsoft, que exige URL pública, e os SDKs comerciais da Apryse/Nutrient são pagos; ambos descartados). Candidatas que o construtor deve avaliar (sugestão, não decisão): pdf.js/`react-pdf` para PDF e `docx-preview` para DOCX.
- **Outros tipos** (zip, pptx, xlsx etc. na v1): a janela mostra **nome, tipo, tamanho e botão de baixar**.
- No app, a Biblioteca virá depois, só consulta e download.

### 4.5 Envio de qualquer tipo de arquivo
- O usuário quer poder enviar **qualquer tipo**, principalmente PDF e DOCX.
- Hoje as regras do Storage e do Firestore aceitam só uma lista de tipos. Abrir a lista é **afrouxar** regra (permitido), mas exige **novo deploy de regras**. Manter limite de tamanho e o restante da validação.

## 5. Restrições
- Mesmo projeto Firebase e login do app; papéis por custom claims (`admin`, `teaching_role`) como hoje.
- Regras do Firestore: apenas mudanças aditivas ou que afrouxam o estritamente necessário; **não apertar** regras existentes.
- Deploy de regras, Functions e Vercel (via merge em `master`) só com autorização do usuário no momento.
- Execução por subagentes **somente Sonnet** (diretriz do usuário).
- Texto da interface em pt-BR.

## 6. Decisões minhas (marcadas como chute, para o usuário conferir)
1. **Dados existentes** (decisão do usuário, 2026-10-25): **esquecer os itens antigos**. A biblioteca é implementada **completa, do zero**, sem migração. O construtor decide se reaproveita a coleção `teaching_items` (e as Functions, regras e telas do Plano B) ou cria estruturas novas, o que for mais limpo; qualquer que seja o caminho, **não apertar** regras existentes e ajustar/retirar o código antigo de pastas.
2. **Pastas**: removidas da interface e do modelo novo; regras existentes não são removidas (seria apertar).
3. **Edição de tags depois de publicado**: curadores também podem corrigir tags de arquivos **já publicados** (o usuário só disse "no momento das revisões").
4. **Pedidos de exclusão** de arquivos publicados aparecem na Fila de Revisão para curadores (é "revisão"), como hoje.
5. **Item devolvido que o autor nunca reenvia** continua sem forma de remoção; lacuna conhecida do projeto anterior, decisão de produto em aberto (exigiria ajuste de regra e da UI).
6. **Filtros combinam assim**: dentro de um tipo de tag, "ou"; entre tipos de tag, "e".
7. A janela de visualização mostra também as tags, o autor e, na Fila de Revisão, os controles de revisão (votar/comentar/editar tags).

8. **Editar tags não zera aprovações**: tags são metadados. A edição **não** muda `version` nem invalida votos já dados; fica registrada no log de auditoria (`teaching_log`) com quem mudou e o que mudou, e o autor recebe notificação. Risco aceito: um curador pode mudar tags depois de outro ter aprovado; o log existe para rastrear isso.
9. **Regra de escrita das tags**: acréscimo aditivo nas regras do Firestore permitindo a curadores alterarem **somente** o campo de tags do item, em qualquer status. O autor altera tags apenas ao reenviar um item devolvido (como hoje com os demais campos). Nenhuma regra existente é apertada.
10. **Visualização sem URL pública**: o navegador lê os bytes pelo SDK autenticado do Storage. Isso provavelmente exige uma **configuração de CORS no bucket** (infraestrutura fora do repositório). Assumo que é aceitável, e o construtor pede autorização ao usuário na hora de aplicar. Se não for, a alternativa seria uma Function como proxy (muito mais trabalho).
11. **Validação das tags**: "pelo menos uma tag de cada tipo" vale para todo envio e reenvio (sem exceções para itens antigos, que não existem mais).
12. **Busca, filtros e paginação (requisito de escala, decisão do usuário)**: hoje o acervo é pequeno, mas **vai crescer progressivamente**; a estrutura de filtros, pesquisa e paginação deve ser **bem otimizada desde já**. Portanto **não** carregar tudo e filtrar no navegador. Requisitos: filtro por tags executado na consulta (entre tipos de tag "e", dentro de um tipo "ou"), pesquisa por nome (e, se viável, tags e autor), ordenação e **paginação por cursor** com carregamento incremental, funcionando bem com milhares de itens e respeitando as regras (somente publicados na Biblioteca). O construtor escolhe a técnica (índices compostos do Firestore, campos derivados como tokens de busca ou tags achatadas, etc.). **Se a solução exigir um serviço externo de busca com custo** (Algolia, Typesense etc.), o construtor deve parar e consultar o usuário antes. Índices compostos novos são aceitáveis (a restrição "sem índices" era do plano anterior, não do usuário); exigem deploy de índices com autorização.

## 7. A confirmar com o usuário
- Faixas "ADULTOS", "CASAIS" e "HOMENS" por extenso ou com sigla; e as decisões da seção 6.
- Faixas "ADULTOS", "CASAIS" e "HOMENS": manter por extenso ou criar siglas?
- As decisões marcadas na seção 6.

## 8. O que fica para o construtor
Formato dos documentos de tag e nome da coleção; como guardar as tags no item (ids vs nomes) e manter a busca/filtro sem índices compostos; mudanças exatas em regras do Firestore/Storage e nas Functions (inclusive validação "pelo menos uma tag de cada tipo" na criação e no reenvio); estratégia de leitura da biblioteca (somente `published`) e da Fila (itens próprios + a revisar); componentes e bibliotecas da visualização; migração de código existente (remoção de pastas da interface, ajuste dos testes); ordem das tarefas.

## 9. Fora deste projeto, em ordem (definida pelo usuário)
1. Fórum de professores (app + web).
2. Planilha do plano pedagógico como tela do app (acompanhar e editar).
3. Biblioteca no app Flutter (consulta e download).
