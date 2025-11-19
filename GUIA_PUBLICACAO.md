# Guia Completo de Publicação - App IPE

Este documento contém o passo a passo completo para publicar o app IPE nas lojas Apple App Store e Google Play Store.

## 📋 Checklist Pré-Publicação

### ✅ Configurações Já Realizadas

- [x] Descrição do app atualizada no `pubspec.yaml`
- [x] Nome do app configurado corretamente (Android: "IPE", iOS: "IPE")
- [x] Permissões adicionadas no AndroidManifest.xml
- [x] Arquivo PrivacyInfo.xcprivacy criado para iOS
- [x] Código de debug otimizado (prints condicionais)
- [x] Configurações de ProGuard para Android
- [x] Bundle ID configurado: `com.ipe.app`

### ⚠️ Ações Necessárias Antes de Publicar

- [ ] **Configurar assinatura de release no Android** (ver seção Android)
- [ ] **Obter App ID da Apple após publicação** (para atualizar link de compartilhamento)
- [ ] **Preparar assets de marketing** (screenshots, descrição, etc.)
- [ ] **Testar build de release** em dispositivos físicos

---

## 🍎 Publicação na Apple App Store

### 1. Preparar Conta de Desenvolvedor Apple

1. **Efetuar Pagamento da Conta**
   - Acesse [developer.apple.com](https://developer.apple.com)
   - Faça login e efetue o pagamento de $99/ano
   - Aguarde a confirmação (geralmente instantânea)

2. **Verificar Informações da Conta**
   - Vá em Account → Membership
   - Anote seu **Team ID** (você precisará dele)

### 2. Criar App ID no Apple Developer Portal

1. **Acesse o Portal**
   - Vá para "Certificates, Identifiers & Profiles"
   - Clique em "Identifiers"

2. **Criar App ID**
   - Clique no botão "+"
   - Selecione "App IDs" → Continue
   - Escolha "App" → Continue
   - Preencha:
     - **Description**: IPE
     - **Bundle ID**: `com.ipe.app` (deve corresponder ao do projeto)
   - Em "Capabilities", marque:
     - ✅ Sign In with Apple (se usar)
     - ✅ Push Notifications (se usar)
   - Clique "Continue" e "Register"

### 3. Criar Certificados e Provisioning Profiles

1. **Certificado de Distribuição**
   - Vá para "Certificates" → "+"
   - Selecione "Apple Distribution" → Continue
   - Siga as instruções para gerar via Keychain Access
   - Baixe e instale o certificado

2. **Provisioning Profile para App Store**
   - Vá para "Profiles" → "+"
   - Selecione "App Store" → Continue
   - Selecione o App ID criado (`com.ipe.app`)
   - Selecione o certificado de distribuição
   - Dê um nome: "IPE App Store"
   - Baixe e instale o perfil

### 4. Configurar o Projeto no Xcode

1. **Abrir o Projeto**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Configurar Signing**
   - Selecione o target "Runner"
   - Vá para "Signing & Capabilities"
   - Marque "Automatically manage signing"
   - Selecione seu Team
   - Verifique que o Bundle Identifier é `com.ipe.app`

3. **Adicionar Capabilities (se necessário)**
   - Se usar Sign In with Apple, adicione a capability
   - Configure conforme necessário

4. **Configurar Versão**
   - O arquivo `Info.plist` já está configurado para usar variáveis do Flutter
   - A versão é controlada pelo `pubspec.yaml` (atualmente: 1.0.0+1)

### 5. Preparar App Store Connect

1. **Acessar App Store Connect**
   - Vá para [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Faça login com sua conta de desenvolvedor

2. **Criar Novo App**
   - Clique em "Meus Apps" → "+" → "Novo App"
   - Preencha:
     - **Nome**: IPE
     - **Idioma Principal**: Português (Brasil)
     - **Bundle ID**: Selecione `com.ipe.app`
     - **SKU**: `com.ipe.app` (identificador único)
     - **ID do Usuário**: Seu ID (geralmente automático)
   - Clique "Criar"

3. **Preencher Informações do App**
   - **Categoria**: Selecione a categoria apropriada
   - **Preço**: Configure se for pago (ou grátis)
   - **Disponibilidade**: Selecione países

4. **Adicionar Informações de Versão**
   - Versão: 1.0.0
   - Direitos autorais: Seus dados
   - Descrição: Descrição do app
   - Palavras-chave: Palavras relevantes
   - URL de Suporte: (se tiver)
   - URL de Marketing: (se tiver)

5. **Preparar Assets**
   - **Ícone do App**: 1024x1024 pixels (PNG sem transparência)
   - **Screenshots**: 
     - iPhone: 6.5" (1290x2796) e 5.5" (1242x2208)
     - iPad: 12.9" (2048x2732) se suportar iPad
   - **Preview**: Vídeo opcional (até 30 segundos)

### 6. Build e Upload do App

1. **Fazer Build do App**
   ```bash
   cd /Users/arcenojackson/www/app_ipe/ipe_flutter
   flutter clean
   flutter pub get
   flutter build ios --release
   ```

2. **Arquivar no Xcode**
   - Abra `ios/Runner.xcworkspace` no Xcode
   - Selecione "Any iOS Device" no esquema
   - Menu: Product → Archive
   - Aguarde o processo completar

3. **Upload para App Store Connect**
   - Na janela do Organizer, clique em "Distribute App"
   - Selecione "App Store Connect"
   - Escolha "Upload"
   - Selecione o profile de distribuição
   - Aguarde o upload completar

4. **Processamento**
   - O app será processado (pode levar algumas horas)
   - Você receberá um email quando estiver pronto

### 7. Submeter para Revisão

1. **No App Store Connect**
   - Vá para a seção "Versão iOS"
   - Clique em "+ Versão" se necessário
   - Preencha todas as informações obrigatórias
   - Selecione o build processado
   - Preencha informações de exportação (se aplicável)
   - Clique "Enviar para Revisão"

2. **Aguardar Revisão**
   - Revisão geralmente leva 24-48 horas
   - Você será notificado por email sobre o status

3. **Atualizar Link de Compartilhamento**
   - Após aprovação, anote o App ID
   - Atualize o link em `lib/src/modules/people/presentation/widgets/invite_person_sheet.dart`
   - Substitua o placeholder pelo ID real

---

## 🤖 Publicação na Google Play Store

### 1. Preparar Conta de Desenvolvedor Google

1. **Criar Conta**
   - Acesse [play.google.com/console](https://play.google.com/console)
   - Pague a taxa única de $25
   - Aguarde aprovação (geralmente instantânea)

2. **Completar Perfil de Desenvolvedor**
   - Preencha informações da conta
   - Configure forma de pagamento (se vender apps)

### 2. Configurar Assinatura do App Android

⚠️ **IMPORTANTE**: Este é um passo crítico que você deve fazer antes de publicar.

1. **Gerar Keystore**
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   - Guarde a senha em local seguro!
   - Responda às perguntas (nome, organização, etc.)

2. **Criar arquivo key.properties**
   ```bash
   cd android
   nano key.properties
   ```
   
   Adicione:
   ```properties
   storePassword=sua_senha_da_keystore
   keyPassword=sua_senha_do_alias
   keyAlias=upload
   storeFile=/caminho/para/upload-keystore.jks
   ```
   
   ⚠️ **IMPORTANTE**: Adicione `key.properties` ao `.gitignore` para não versionar!

3. **Configurar build.gradle.kts**
   
   Você precisará editar `android/app/build.gradle.kts` para usar a keystore:
   
   ```kotlin
   // Adicione no início do arquivo (antes de android {)
   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }
   
   android {
       // ... configurações existentes ...
       
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String
               keyPassword = keystoreProperties["keyPassword"] as String
               storeFile = file(keystoreProperties["storeFile"] as String)
               storePassword = keystoreProperties["storePassword"] as String
           }
       }
       
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
               // ... resto das configurações ...
           }
       }
   }
   ```

### 3. Criar App no Google Play Console

1. **Acessar Console**
   - Vá para [play.google.com/console](https://play.google.com/console)
   - Clique em "Criar app"

2. **Informações Básicas**
   - **Nome do app**: IPE
   - **Idioma padrão**: Português (Brasil)
   - **Tipo de app**: App
   - **Grátis ou pago**: Escolha conforme necessário
   - Marque os checkboxes de política
   - Clique "Criar app"

### 4. Configurar Store Listing

1. **Preencher Informações**
   - **Descrição curta**: (até 80 caracteres)
   - **Descrição completa**: Descrição detalhada do app
   - **Screenshots**: 
     - Pelo menos 2 screenshots (1080x1920 para telefones)
     - Tablets: Se suportar (1280x800)
   - **Ícone**: 512x512 pixels (PNG)
   - **Feature Graphic**: 1024x500 pixels
   - **Categoria**: Selecione a apropriada

2. **Classificação de Conteúdo**
   - Responda o questionário
   - Salve as respostas

### 5. Build e Upload do App

1. **Fazer Build de Release**
   ```bash
   cd /Users/arcenojackson/www/app_ipe/ipe_flutter
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```
   
   Isso gerará: `build/app/outputs/bundle/release/app-release.aab`

2. **Upload no Play Console**
   - Vá para "Produção" (ou "Teste interno" para testar primeiro)
   - Clique "Criar nova versão"
   - Faça upload do arquivo `.aab`
   - Preencha "Notas da versão"
   - Clique "Salvar"

### 6. Completar Verificações

1. **Política de Conteúdo**
   - Preencha todas as seções necessárias
   - Responda sobre privacidade de dados

2. **Configurações de App**
   - Configure categoria e tags
   - Defina restrições de conteúdo (se houver)

3. **Preços e Distribuição**
   - Configure países de distribuição
   - Configure preço (se pago)

### 7. Submeter para Revisão

1. **Verificar Checklist**
   - Certifique-se de que todas as seções estão completas
   - Ícone adicionado
   - Pelo menos 2 screenshots
   - Descrição preenchida
   - Política de privacidade (se coletar dados)

2. **Enviar para Revisão**
   - Clique em "Enviar para revisão"
   - Aguarde aprovação (geralmente 1-3 dias)

---

## 📱 Verificações Finais

### Testes Obrigatórios

Antes de publicar, teste:

- [ ] Login funciona corretamente
- [ ] Todas as funcionalidades principais
- [ ] Performance em dispositivos físicos
- [ ] Não há crashes
- [ ] Firebase está funcionando
- [ ] Analytics está coletando dados

### Builds de Teste

Recomenda-se testar em:

1. **TestFlight (iOS)**
   - Faça upload como beta
   - Convide testadores
   - Teste antes de publicar

2. **Google Play Internal Testing (Android)**
   - Use "Teste interno" no Play Console
   - Adicione testadores por email
   - Teste antes de publicar em produção

---

## 🔄 Atualizações Futuras

### Para Nova Versão

1. **Atualizar Versão**
   - Edite `pubspec.yaml`: `version: 1.0.1+2`
   - Primeiro número: versão pública
   - Segundo número: build number (sempre incrementar)

2. **Build e Upload**
   - Siga os mesmos passos de build
   - Faça upload como nova versão nas lojas

### Mantendo Chaves Seguras

- ⚠️ **NUNCA** commite a keystore no git
- ⚠️ **NUNCA** commite `key.properties` no git
- Guarde backups da keystore em local seguro
- Sem a keystore, você não poderá atualizar o app!

---

## 📝 Resumo de Informações Importantes

### iOS
- **Bundle ID**: `com.ipe.app`
- **App Name**: IPE
- **Versão Atual**: 1.0.0+1

### Android
- **Package Name**: `com.ipe.app`
- **App Name**: IPE
- **Versão Atual**: 1.0.0+1
- **Keystore**: `~/upload-keystore.jks` (após criar)

### Links Úteis

- Apple Developer: https://developer.apple.com
- App Store Connect: https://appstoreconnect.apple.com
- Google Play Console: https://play.google.com/console
- Documentação Flutter: https://flutter.dev/docs/deployment

---

## ⚠️ Problemas Comuns

### iOS

**Erro de assinatura**: Verifique se o certificado e profile estão instalados no Keychain

**Build não aparece no App Store Connect**: Aguarde processamento (até 24h)

### Android

**Erro de assinatura**: Verifique se `key.properties` está correto e a keystore existe

**App não instala**: Verifique se está usando o mesmo certificado da versão anterior

---

Boa sorte com a publicação! 🚀

