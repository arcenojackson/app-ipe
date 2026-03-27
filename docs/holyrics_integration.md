O objetivo do documento é:

* explicar **contexto do App IPE**
* explicar **integração local com Holyrics**
* definir **escopo do MVP (Fase 1)**
* definir **arquitetura técnica**
* definir **modelo de dados**
* definir **fluxos**
* definir **contratos HTTP**
* definir **tarefas de implementação**

Assim a IA do Cursor terá **contexto suficiente para gerar código consistente com o app existente em Flutter + Firebase**.

---

```markdown
# Integração App IPE + Holyrics
## Fase 1 — Controle e envio de liturgia via API local

Autor: Jackson Arceno  
Projeto: App IPE (Igreja Presbiteriana do Estreito)  
Tecnologia do app: Flutter + Firebase  
Objetivo: integração local com o software Holyrics

---

# 1. Contexto do Projeto

O **App IPE** é um aplicativo mobile desenvolvido para uso interno da Igreja Presbiteriana do Estreito.

Ele é utilizado principalmente pela **equipe de música da igreja**, mas também possui funcionalidades para diretorias e equipes internas.

Entre as funcionalidades existentes estão:

- organização de escalas
- organização de equipes
- comunicação interna
- outras ferramentas de apoio à equipe de música

Uma nova funcionalidade será criada para permitir a **organização de liturgias de cultos e eventos**.

---

# 2. Problema a ser resolvido

Hoje a equipe de projeção utiliza o software **Holyrics** para projetar:

- letras de músicas
- textos bíblicos
- textos litúrgicos
- avisos
- outros conteúdos

O Holyrics roda em **um computador local na igreja**.

Atualmente a preparação da liturgia e da projeção são processos separados.

Isso gera:

- retrabalho
- risco de erro
- tempo adicional de preparação

---

# 3. Objetivo da Integração

Permitir que o **App IPE envie informações da liturgia diretamente para o Holyrics**, reduzindo trabalho manual da equipe de projeção.

A integração será feita usando a **API HTTP local do Holyrics**.

Importante:

- Não haverá servidor intermediário
- Não haverá exposição do Holyrics na internet
- Tudo acontecerá **apenas na rede local da igreja**

---

# 4. Arquitetura

Arquitetura simplificada:

```

App IPE (Flutter)
|
| HTTP local (WiFi igreja)
|
Holyrics API Server
|
Computador da projeção

```

Requisitos:

- celular e computador devem estar na **mesma rede WiFi**
- o **API Server do Holyrics deve estar habilitado**
- a porta da API deve estar liberada no firewall

---

# 5. Escopo da Fase 1 (MVP)

A Fase 1 terá **integração unidirecional**.

Ou seja:

```

App IPE → Holyrics

```

Sem sincronização reversa.

## Funcionalidades do MVP

1️⃣ Configurar conexão com Holyrics  
2️⃣ Testar conexão  
3️⃣ Enviar liturgia para Holyrics  
4️⃣ Abrir etapa específica da liturgia no Holyrics  
5️⃣ Avançar ou voltar etapas da liturgia

---

# 6. Configuração da Integração

Criar uma tela no App IPE:

## Configurações > Integrações > Holyrics

Campos:

```

Holyrics IP
Holyrics Port
API Token

```

Exemplo:

```

IP: 192.168.0.10
Porta: 8080
Token: abc123

```

Botão:

```

Testar conexão

```

---

# 7. Estrutura da Liturgia no App

A liturgia é composta por **etapas**.

Exemplo:

```

1 - Abertura
2 - Cântico
3 - Leitura Bíblica
4 - Oração
5 - Cântico
6 - Pregação
7 - Avisos

```

Cada etapa possui um tipo.

## Tipos de etapa

```

song
bible
text
custom

````

---

# 8. Modelo de dados sugerido

```dart
class Liturgy {
  String id;
  String title;
  DateTime date;
  List<LiturgyItem> items;
}

class LiturgyItem {
  String id;
  String title;
  LiturgyItemType type;
  Map<String, dynamic> data;
}

enum LiturgyItemType {
  song,
  bible,
  text,
  custom
}
````

---

# 9. Exemplos de itens

## Música

```
type: song
data:
  title: "Grande é o Senhor"
```

## Texto Bíblico

```
type: bible
data:
  book: "Salmos"
  chapter: 23
  startVerse: 1
  endVerse: 6
```

## Texto

```
type: text
data:
  content: "Confissão de fé"
```

---

# 10. Enviar Liturgia para Holyrics

Na tela da liturgia haverá um botão:

```
Enviar para Holyrics
```

Fluxo:

1. Validar conexão
2. Percorrer itens da liturgia
3. Mapear cada item para uma ação da API
4. Enviar requisição HTTP

---

# 11. Cliente Holyrics

Criar um serviço no Flutter:

```
HolyricsService
```

Responsável por:

* comunicação HTTP
* autenticação
* envio de comandos

---

# 12. Estrutura do serviço

```dart
class HolyricsService {

  Future<bool> testConnection();

  Future<void> showSong(String songTitle);

  Future<void> showBibleVerse(
    String book,
    int chapter,
    int startVerse,
    int endVerse,
  );

  Future<void> showText(String text);

}
```

---

# 13. Endpoint base

Exemplo:

```
http://{ip}:{port}/api
```

Exemplo real:

```
http://192.168.0.10:8080/api
```

---

# 14. Teste de conexão

Endpoint simples.

Retorna sucesso se API responder.

---

# 15. Mapear tipos de item

```
song  -> showSong
bible -> showVerse
text  -> showText
```

---

# 16. Fluxo "Enviar Liturgia"

Pseudo código:

```
for item in liturgy.items:

  if item.type == song:
      holyrics.showSong()

  if item.type == bible:
      holyrics.showBibleVerse()

  if item.type == text:
      holyrics.showText()
```

---

# 17. Controle ao vivo

Opcional na Fase 1.

Botões:

```
Mostrar etapa atual
Próxima etapa
Etapa anterior
```

---

# 18. Tratamento de erros

Casos:

* Holyrics offline
* erro de rede
* timeout
* item inexistente

Mostrar mensagem amigável.

Exemplo:

```
Não foi possível conectar ao Holyrics.
Verifique se você está no WiFi da igreja.
```

---

# 19. Segurança

* Token obrigatório
* Não expor API na internet
* Comunicação apenas na rede local

---

# 20. Futuras evoluções (Fase 2)

Funcionalidades planejadas:

* sincronização da liturgia com playlists do Holyrics
* criação automática de músicas
* criação automática de textos
* verificação se item já existe

---

# 21. Futuras evoluções (Fase 3)

Sincronização bidirecional:

```
Holyrics → App IPE
```

Possibilidades:

* mostrar etapa atual da projeção
* indicador de progresso da liturgia
* modo "Play"

---

# 22. Objetivo do MVP

Reduzir o trabalho da equipe de projeção e permitir que a **liturgia preparada no App IPE seja facilmente executada no Holyrics**.

---

# 23. Critérios de sucesso

A funcionalidade será considerada concluída quando for possível:

✔ configurar IP do Holyrics
✔ testar conexão
✔ enviar liturgia
✔ abrir música
✔ abrir texto bíblico
✔ abrir texto

---

# 24. Observação importante

Esta integração deve funcionar **apenas dentro da rede local da igreja**, não sendo necessário backend adicional além do Firebase já utilizado pelo App IPE.

---

# Fim do documento

```

---

💡 **Dica importante para usar no Cursor**

Depois de adicionar esse arquivo no projeto, você pode pedir algo como:

> “Use o documento `holyrics_integration_phase1.md` como contexto e implemente a camada `HolyricsService` em Flutter, incluindo cliente HTTP, configuração persistida e teste de conexão.”

Isso costuma fazer a IA gerar código **bem mais alinhado ao projeto**.

---

Se quiser, eu também posso montar para você **mais três arquivos que ajudam MUITO a IA do Cursor**:

1️⃣ `holyrics_service.dart` (interface pronta)  
2️⃣ `holyrics_repository.dart`  
3️⃣ `holyrics_settings_screen.md` (especificação da tela Flutter)

Isso normalmente **acelera absurdamente a implementação**.
```

