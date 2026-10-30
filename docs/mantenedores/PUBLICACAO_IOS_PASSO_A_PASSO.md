# 📱 Guia Passo a Passo - Publicação na Apple App Store

Este guia te levará do zero até ter seu app publicado na App Store.

---

## ✅ Checklist de Pré-requisitos

- [x] Conta Apple Developer ativa ($99/ano)
- [x] Acesso ao App Store Connect
- [x] Bundle ID configurado: `com.ipe.app`
- [x] Versão do app: 1.0.0+1
- [x] Ícones configurados
- [x] Nome do app: "App IPE"

---

## 📋 PASSO 1: Criar App ID no Apple Developer Portal

### 1.1 Acessar o Portal

1. Vá para [developer.apple.com](https://developer.apple.com)
2. Faça login com sua conta de desenvolvedor
3. Clique em **"Certificates, Identifiers & Profiles"**

### 1.2 Criar o App ID

1. No menu lateral, clique em **"Identifiers"**
2. Clique no botão **"+"** no canto superior direito
3. Selecione **"App IDs"** → Clique **"Continue"**
4. Escolha **"App"** → Clique **"Continue"**
5. Preencha os dados:
   - **Description**: `App IPE` (ou apenas `IPE`)
   - **Bundle ID**: Selecione **"Explicit"** e digite: `com.ipe.app`
6. Em **"Capabilities"**, marque apenas o que você usa:
   - ✅ **Sign In with Apple** (se você usa login com Apple)
   - ✅ **Push Notifications** (se você usa notificações)
   - ✅ **Associated Domains** (se necessário)
7. Clique **"Continue"** → Clique **"Register"**

✅ **Resultado esperado**: App ID `com.ipe.app` criado e registrado.

---

## 📋 PASSO 2: Configurar Assinatura no Xcode (Automático)

A maneira mais fácil é usar a assinatura automática do Xcode:

### 2.1 Abrir o Projeto no Xcode

```bash
cd /Users/arcenojackson/www/app_ipe/ipe_flutter/ios
open Runner.xcworkspace
```

⚠️ **IMPORTANTE**: Use `.xcworkspace` (não `.xcodeproj`) para projetos com CocoaPods!

### 2.2 Configurar Signing & Capabilities

1. No Xcode, selecione o projeto **"Runner"** no navegador à esquerda
2. Selecione o target **"Runner"** (não o projeto)
3. Vá para a aba **"Signing & Capabilities"**
4. Marque **"Automatically manage signing"**
5. Em **"Team"**, selecione sua equipe de desenvolvedor Apple
6. Verifique que **Bundle Identifier** está como `com.ipe.app`

✅ O Xcode criará automaticamente:
   - Certificado de Distribuição
   - Provisioning Profile

### 2.3 Verificar Capabilities (se necessário)

Se você usa **Sign In with Apple**:
1. Clique no botão **"+ Capability"**
2. Adicione **"Sign In with Apple"**
3. Configure se necessário

✅ **Resultado esperado**: Projeto configurado com assinatura automática.

---

## 📋 PASSO 3: Criar o App no App Store Connect

### 3.1 Acessar App Store Connect

1. Vá para [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Faça login com sua conta de desenvolvedor

### 3.2 Criar Novo App

1. Clique em **"Meus Apps"** (ou "My Apps")
2. Clique no botão **"+"** → **"Novo App"** (ou "New App")

### 3.3 Preencher Informações Básicas

Preencha os campos:

- **Plataformas**: Marque apenas **iOS** (por enquanto)
- **Nome**: `App IPE` (ou `IPE`)
- **Idioma Principal**: **Português (Brasil)**
- **Bundle ID**: Selecione `com.ipe.app` da lista (deve aparecer após criar o App ID)
- **SKU**: `com.ipe.app` (ou qualquer identificador único, ex: `app-ipe-001`)
- **ID do Usuário**: Deixe em branco ou use o padrão

Clique em **"Criar"** (ou "Create")

✅ **Resultado esperado**: App criado no App Store Connect.

---

## 📋 PASSO 4: Preparar Informações e Assets

Antes de fazer o upload, você precisa preparar:

### 4.1 Informações Necessárias

Prepare os seguintes textos:

- **Descrição**: Descrição do seu app (até 4000 caracteres)
- **Palavras-chave**: Palavras separadas por vírgula (até 100 caracteres)
- **URL de Suporte**: (Opcional) Link para suporte/site
- **URL de Marketing**: (Opcional) Link para site do app
- **Direitos autorais**: Seus dados (ex: "© 2025 Seu Nome")

### 4.2 Assets Necessários

1. **Ícone do App**: ✅ Já está pronto (1024x1024px)

2. **Screenshots** (obrigatórios):
   - **iPhone 6.5"** (iPhone 14 Pro Max): 1290 x 2796 pixels
   - **iPhone 5.5"** (iPhone 8 Plus): 1242 x 2208 pixels
   - **iPad Pro 12.9"**: 2048 x 2732 pixels (se suportar iPad)

   📸 **Como capturar**:
   - Use o simulador do iOS no Xcode
   - Ou capture em um dispositivo físico
   - Tire pelo menos 2-3 screenshots mostrando as funcionalidades principais

3. **Preview de Vídeo** (opcional): Até 30 segundos mostrando o app

### 4.3 Configurações do App

Decida:
- **Categoria Primária**: Escolha a categoria mais apropriada
- **Categoria Secundária**: (Opcional)
- **Preço**: Grátis ou pago? (Se pago, configure o preço)
- **Idade**: Classificação de conteúdo
- **Disponibilidade**: Em quais países? (recomendo: Todos)

---

## 📋 PASSO 5: Build e Upload do App

### 5.1 Limpar e Preparar o Projeto

```bash
cd /Users/arcenojackson/www/app_ipe/ipe_flutter
flutter clean
flutter pub get
```

### 5.2 Fazer Build para iOS

```bash
flutter build ios --release
```

Este comando vai:
- Compilar o app em modo release
- Gerar os arquivos necessários para arquivamento

### 5.3 Arquivar no Xcode

1. No Xcode, certifique-se que o esquema está selecionado como **"Any iOS Device"** (não um simulador específico)
2. No menu superior, vá em **Product** → **Archive**
3. Aguarde o processo completar (pode levar alguns minutos)

### 5.4 Upload para App Store Connect

Após o arquivamento:

1. A janela **Organizer** deve abrir automaticamente
2. Selecione o archive que acabou de criar
3. Clique em **"Distribute App"**
4. Selecione **"App Store Connect"**
5. Clique **"Next"**
6. Selecione **"Upload"**
7. Clique **"Next"**
8. Revise as opções (deixe os padrões)
9. Clique **"Next"**
10. Selecione sua equipe de distribuição
11. Clique **"Next"**
12. Revise todas as informações
13. Clique **"Upload"**

✅ **Resultado esperado**: App enviado para App Store Connect. Aguarde processamento (15 minutos a algumas horas).

---

## 📋 PASSO 6: Completar Informações no App Store Connect

Enquanto o app está sendo processado, você pode completar as informações:

### 6.1 Acessar a Versão do App

1. No App Store Connect, vá em **"Meus Apps"**
2. Clique no app **"App IPE"**
3. Clique na seção **"Versão iOS"** (ou "iOS Version")

### 6.2 Preencher Informações de Versão

1. **Sobre esta versão**:
   - Adicione a descrição do app
   - Adicione palavras-chave
   - Adicione URL de suporte (se tiver)
   - Adicione URL de marketing (se tiver)

2. **Screenshots**:
   - Clique em cada tamanho necessário
   - Faça upload dos screenshots correspondentes
   - Ordene-os (o primeiro será o principal)

3. **Ícone do App**:
   - O ícone 1024x1024 deve ser enviado automaticamente
   - Se não, faça upload manualmente

4. **Classificação de Conteúdo**:
   - Responda o questionário sobre o conteúdo do app
   - Salve as respostas

5. **Informações de Aplicação**:
   - **Categoria**: Selecione primária e secundária
   - **Direitos autorais**: Seus dados
   - **Avisos legais**: (se necessário)

6. **Preço e Disponibilidade**:
   - Configure o preço (grátis ou pago)
   - Selecione países/regiões de disponibilidade

### 6.3 Selecionar o Build

Após o processamento estar completo:

1. Na seção **"Build"**, clique em **"+ Build"**
2. Selecione o build processado (ele aparecerá quando estiver pronto)
3. Se não aparecer, aguarde mais alguns minutos/horas

---

## 📋 PASSO 7: Submeter para Revisão

### 7.1 Revisar Checklist

Antes de submeter, verifique:

- [ ] Build selecionado e processado
- [ ] Ícone do app adicionado
- [ ] Pelo menos 2 screenshots adicionados
- [ ] Descrição completa preenchida
- [ ] Palavras-chave preenchidas
- [ ] Classificação de conteúdo concluída
- [ ] Categoria selecionada
- [ ] Informações de contato preenchidas
- [ ] Política de privacidade (se o app coleta dados)

### 7.2 Informações de Exportação (se necessário)

Se o app usa criptografia (muitos apps usam):

1. Em **"Informações de Exportação"**, responda se necessário
2. Para a maioria dos apps, a resposta padrão está correta

### 7.3 Submeter

1. Role até o final da página
2. Clique em **"Adicionar para revisão"** ou **"Enviar para revisão"**
3. Confirme a submissão

✅ **Resultado esperado**: App enviado para revisão da Apple.

---

## ⏳ PASSO 8: Aguardar Revisão

### Tempo Estimado

- **Processamento do build**: 15 minutos a 2 horas
- **Revisão da Apple**: 24 a 48 horas (às vezes mais)

### Você Receberá Emails

1. **Build processado**: Quando o upload for processado
2. **Em revisão**: Quando a Apple começar a revisar
3. **Aprovado**: Quando o app for aprovado
4. **Rejeitado**: Se houver problemas (com explicação)

### Status no App Store Connect

Você pode acompanhar o status:
- **Preparando para envio**
- **Aguardando revisão**
- **Em revisão**
- **Pendente de publicação** (aprovado)
- **Pronto para venda** (publicado)

---

## 🎉 PASSO 9: App Publicado!

### Após Aprovação

1. Você receberá um email de aprovação
2. O app ficará no status **"Pendente de publicação"**
3. Geralmente, o app é publicado automaticamente em poucas horas
4. Você pode publicar manualmente ou agendar

### Após Publicação

1. O app estará disponível na App Store em algumas horas
2. Você receberá um email confirmando a publicação
3. **Importante**: Anote o App ID do app na App Store (necessário para atualizar o link de compartilhamento)

---

## 🔄 Atualizar Link de Compartilhamento (Após Publicação)

Após o app ser publicado:

1. Acesse o App Store Connect
2. Vá para o app **"App IPE"**
3. Anote o **App ID** (número, ex: `1234567890`)
4. Atualize o link no código:

```dart
// Em lib/src/modules/people/presentation/widgets/invite_person_sheet.dart
String _getAppStoreLink() {
  if (Platform.isIOS) {
    return 'https://apps.apple.com/app/app-ipe/id[SEU_APP_ID_AQUI]';
  }
  // ...
}
```

5. Faça um novo build e submeta como atualização

---

## ⚠️ Problemas Comuns e Soluções

### ❌ Erro de Assinatura

**Problema**: Erro ao arquivar relacionado à assinatura

**Solução**:
- Verifique se o Team está selecionado no Xcode
- Certifique-se que "Automatically manage signing" está marcado
- Limpe o build: `flutter clean` e tente novamente

### ❌ Build Não Aparece no App Store Connect

**Problema**: Build não aparece na lista de builds disponíveis

**Solução**:
- Aguarde mais tempo (pode levar até 2 horas)
- Verifique se o build foi processado corretamente
- Verifique se o Bundle ID corresponde exatamente

### ❌ App Rejeitado na Revisão

**Problema**: Apple rejeitou o app

**Solução**:
- Leia cuidadosamente o email de rejeição
- Corrija os problemas mencionados
- Responda à Apple explicando as correções
- Reenvie o app

### ❌ Erro de Criptografia

**Problema**: Pergunta sobre exportação de criptografia

**Solução**:
- A maioria dos apps usa HTTPS, que é considerado criptografia
- Responda conforme orientado no App Store Connect
- Para apps simples, geralmente a resposta padrão está correta

---

## 📞 Links Úteis

- **Apple Developer**: https://developer.apple.com
- **App Store Connect**: https://appstoreconnect.apple.com
- **Documentação Flutter iOS**: https://flutter.dev/docs/deployment/ios
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/

---

## ✅ Resumo Rápido

1. ✅ Criar App ID no Developer Portal
2. ✅ Configurar assinatura no Xcode (automático)
3. ✅ Criar app no App Store Connect
4. ✅ Preparar screenshots e informações
5. ✅ Fazer build e arquivar no Xcode
6. ✅ Upload para App Store Connect
7. ✅ Completar informações do app
8. ✅ Submeter para revisão
9. ✅ Aguardar aprovação
10. ✅ App publicado! 🎉

**Tempo estimado total**: 2-4 dias (maior parte é espera pela revisão)

Boa sorte com a publicação! 🚀



