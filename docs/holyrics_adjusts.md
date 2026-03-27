# Integração App IPE → Holyrics (API Local)

Projeto: App IPE  
Stack: Flutter + Firebase  
Objetivo: enviar comandos de liturgia para o Holyrics rodando no computador da igreja usando a API HTTP local.

---

# Visão geral

O Holyrics possui dois serviços diferentes:

1. **Plugin/Web Service**

Exibe links como:

/view/widescreen
/view/text
/chat


Esses endpoints retornam **HTML** e servem apenas para visualização remota.  
Não são usados para integração.

2. **API Server**

Fornece endpoints HTTP que retornam **JSON** e permitem controle do Holyrics via requisições HTTP.

A integração do App IPE deve usar exclusivamente o **API Server**.

---

# Ativação da API no Holyrics

No computador da igreja:

Holyrics → Arquivo → Configurações → API Server


Configurar:

- ativar API Server
- definir porta
- criar token
- definir permissões

Permissões recomendadas:

ShowLyrics
ShowVerse
ShowText
GetSongs
GetTexts
GetTokenInfo


Verificar também:

- firewall liberando a porta
- computador e celular na mesma rede WiFi

---

# Estrutura da API

Formato da URL:

http://IP:PORT/api/{ACTION}?token=TOKEN


Exemplo:

http://192.168.0.117:8080/api/GetSongs?token=abc123


Método HTTP:

POST


Header:

Content-Type: application/json


Body mínimo:

{}


---

# Teste de conexão

Não existe endpoint `/api/test/`.

Para validar a API usar:

POST /api/GetTokenInfo


Exemplo:

POST http://IP:PORT/api/GetTokenInfo?token=TOKEN
Content-Type: application/json

{}


Se retornar JSON válido, a conexão está correta.

Resposta esperada:

{
"success": true
}


---

# Endpoint base no app

Configuração no App IPE:

IP: 192.168.0.117
Porta: 8080
Token: abc123


Base URL:

http://192.168.0.117:8080/api


---

# Cliente Flutter

Criar serviço responsável pelas chamadas HTTP.

Exemplo de estrutura:

```dart
class HolyricsService {

  final String baseUrl;
  final String token;

  HolyricsService(this.baseUrl, this.token);

  Future<bool> testConnection();

  Future<void> showSong(String title);

  Future<void> showVerse(
    String book,
    int chapter,
    int verse
  );

  Future<void> showText(String text);
}
Implementação de testConnection()
Future<bool> testConnection() async {

 final response = await http.post(
   Uri.parse("$baseUrl/GetTokenInfo?token=$token"),
   headers: {
     "Content-Type": "application/json"
   },
   body: "{}"
 );

 return response.statusCode == 200;
}
Comandos principais
Mostrar música
POST /api/ShowLyrics
Body:

{
 "text": "Nome da música"
}
Mostrar versículo
POST /api/ShowVerse
Body:

{
 "book": "Salmos",
 "chapter": 23,
 "verse": 1
}
Mostrar texto
POST /api/ShowText
Body:

{
 "text": "Texto da liturgia"
}
