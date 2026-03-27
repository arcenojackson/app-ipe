# Guia Completo: Implementação do Sign In with Apple

Este guia detalha todos os passos necessários para implementar o Sign In with Apple no aplicativo Flutter, incluindo configurações no Firebase Console, Apple Developer Console e no código do aplicativo.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Configuração no Firebase Console](#configuração-no-firebase-console)
3. [Configuração no Apple Developer Console](#configuração-no-apple-developer-console)
4. [Configuração no Projeto Flutter](#configuração-no-projeto-flutter)
5. [Configuração no Projeto iOS (Xcode)](#configuração-no-projeto-ios-xcode)
6. [Implementação no Código](#implementação-no-código)
7. [Testes](#testes)
8. [Troubleshooting](#troubleshooting)

---

## 🔧 Pré-requisitos

Antes de começar, certifique-se de ter:

- ✅ Conta no Firebase Console
- ✅ Conta no Apple Developer Program (paga)
- ✅ Projeto iOS configurado no Xcode
- ✅ Bundle ID do app configurado no Apple Developer Console
- ✅ Certificados e perfis de provisionamento configurados

---

## 1. Configuração no Firebase Console

### Passo 1.1: Acessar a Configuração de Autenticação

1. Acesse o [Firebase Console](https://console.firebase.google.com/)
2. Selecione seu projeto
3. No menu lateral, vá em **Authentication** (Autenticação)
4. Clique na aba **Sign-in method** (Métodos de entrada)

### Passo 1.2: Ativar o Sign In with Apple

1. Na lista de provedores, encontre **Apple**
2. Clique no provedor **Apple**
3. Ative o toggle **Ativar** (Enable)
4. Você verá uma tela de configuração com as seguintes opções:

   - **Services ID** (não é obrigatório para Apple)
   - **Configuração do fluxo de código OAuth** (opcional)

### Passo 1.3: Copiar o Callback URL

1. Na seção "Configuração do fluxo de código OAuth", você verá:
   - Instruções sobre adicionar o URL de callback
   - Um campo com o URL de callback (exemplo: `https://app-ipe.firebaseapp.com/__/auth/handler`)
2. **Copie este URL** - você precisará dele no Apple Developer Console
3. Clique no ícone de copiar ao lado do URL

### Passo 1.4: Salvar a Configuração

1. Clique em **Salvar** (Save) no final da página
2. O Firebase agora está configurado para aceitar autenticação via Apple

---

## 2. Configuração no Apple Developer Console

### Passo 2.1: Acessar o Apple Developer Console

1. Acesse [developer.apple.com](https://developer.apple.com/)
2. Faça login com sua conta de desenvolvedor
3. Vá em **Certificates, Identifiers & Profiles**

### Passo 2.2: Configurar o App ID

1. No menu lateral, clique em **Identifiers**
2. Selecione seu **App ID** (o mesmo Bundle ID do seu app)
3. Se não tiver um App ID criado:
   - Clique no botão **+** para criar um novo
   - Preencha:
     - **Description**: Nome descritivo do app
     - **Bundle ID**: O mesmo do seu app (ex: `com.ipe.app`)
   - Marque a opção **Sign In with Apple**
   - Clique em **Continue** e depois em **Register**

### Passo 2.3: Habilitar Sign In with Apple no App ID

1. Com o App ID selecionado, role até a seção **Capabilities**
2. Marque a checkbox **Sign In with Apple**
3. Clique em **Configure** ao lado de "Sign In with Apple"
4. Na tela de configuração que abrir:
   - Selecione **"Enable as a primary App ID"** (se for o primeiro App ID ou o principal)
   - Ou selecione **"Group with an existing primary App ID"** (se já tiver um App ID principal)
5. **Server-to-Server Notification Endpoint** (Opcional):
   - Este campo é opcional, mas recomendado se você quiser receber notificações sobre mudanças nas contas dos usuários
   - O Firebase já fornece um endpoint padrão: `https://app-ipe.firebaseapp.com/__/auth/handler`
   - Você pode usar este mesmo URL ou deixar em branco se não precisar de notificações server-to-server
6. Clique em **Save**
7. Volte para a tela anterior e clique em **Continue** e depois em **Save**

### Passo 2.4: Criar Services ID (Opcional, mas Recomendado)

O Services ID é necessário se você quiser usar o Sign In with Apple em múltiplas plataformas (iOS, Web, etc.).

1. No menu lateral, clique em **Identifiers**
2. Clique no botão **+** para criar um novo
3. Selecione **Services IDs** e clique em **Continue**
4. Preencha:
   - **Description**: Nome descritivo (ex: "App IPE Services")
   - **Identifier**: Um identificador único (ex: `com.ipe.app.services`)
5. Clique em **Continue** e depois em **Register**
6. Com o Services ID criado, clique nele para editá-lo
7. Marque a checkbox **Sign In with Apple**
8. Clique em **Configure** ao lado de "Sign In with Apple"

### Passo 2.5: Configurar Domínios e URLs de Retorno

1. Na tela de configuração do Sign In with Apple:
   - **Primary App ID**: Selecione o App ID do seu app
   - **Domains and Subdomains**: Adicione o domínio do Firebase
     - Exemplo: `app-ipe.firebaseapp.com`
   - **Return URLs**: Adicione o URL de callback que você copiou do Firebase
     - Exemplo: `https://app-ipe.firebaseapp.com/__/auth/handler`
2. Clique em **Save**
3. Volte para a tela anterior e clique em **Continue** e depois em **Save**

### Passo 2.6: Criar Key para Autenticação (Opcional)

Se você precisar de autenticação server-side:

1. No menu lateral, clique em **Keys**
2. Clique no botão **+** para criar uma nova key
3. Dê um nome à key
4. Marque **Sign In with Apple**
5. Clique em **Configure** e selecione seu **Primary App ID**
6. Clique em **Save** e depois em **Continue**
7. **IMPORTANTE**: Baixe a key (.p8) - você só poderá baixá-la uma vez!
8. Anote o **Key ID** - você precisará dele

---

## 3. Configuração no Projeto Flutter

### Passo 3.1: Adicionar Dependência

1. Abra o arquivo `pubspec.yaml`
2. Adicione a dependência `sign_in_with_apple`:

```yaml
dependencies:
  sign_in_with_apple: ^6.1.3
```

3. Execute no terminal:

```bash
flutter pub get
```

### Passo 3.2: Verificar Versão Mínima do iOS

No `pubspec.yaml`, certifique-se de que a versão mínima do iOS seja 13.0 ou superior (o Sign In with Apple requer iOS 13+):

```yaml
# Isso é configurado no ios/Podfile ou ios/Runner.xcodeproj
# Verifique que o deployment target seja iOS 13.0 ou superior
```

---

## ⚠️ Antes de Prosseguir para o Passo 4 (Xcode)

Antes de configurar o projeto no Xcode, certifique-se de que:

1. ✅ **Firebase Console**: Sign In with Apple está ativado e você copiou o URL de callback
2. ✅ **Apple Developer Console**: 
   - App ID criado e Sign In with Apple habilitado
   - App ID configurado como "Primary" ou agrupado com um Primary existente
   - Server-to-Server Notification Endpoint configurado (opcional, mas recomendado)
   - Services ID criado e configurado (se necessário para múltiplas plataformas)
   - Domínios e Return URLs configurados no Services ID (se criado)

3. ✅ **Código Flutter**: 
   - Dependência `sign_in_with_apple` adicionada e instalada (`flutter pub get`)
   - Métodos implementados no código (já está pronto ✅)

**Se todas as configurações acima estiverem concluídas, você pode prosseguir para o Passo 4.**

---

## 4. Configuração no Projeto iOS (Xcode)

### Passo 4.1: Abrir o Projeto no Xcode

1. Abra o terminal e navegue até a pasta do projeto
2. Execute:

```bash
cd ios
open Runner.xcworkspace
```

**IMPORTANTE**: Use o `.xcworkspace`, não o `.xcodeproj`

### Passo 4.2: Configurar o Capability "Sign In with Apple"

1. No Xcode, selecione o projeto **Runner** no navegador de arquivos
2. Selecione o target **Runner**
3. Vá na aba **Signing & Capabilities**
4. Clique no botão **+ Capability**
5. Procure e adicione **Sign In with Apple**
6. Isso adicionará automaticamente a capability ao projeto

### Passo 4.3: Verificar o Bundle Identifier

1. Na mesma aba **Signing & Capabilities**
2. Verifique se o **Bundle Identifier** está correto
3. Deve corresponder ao App ID configurado no Apple Developer Console

### Passo 4.4: Configurar o Provisioning Profile

1. Certifique-se de que o **Team** está selecionado corretamente
2. O Xcode deve gerar automaticamente o provisioning profile
3. Se houver erros, você pode precisar:
   - Atualizar os certificados no Apple Developer Console
   - Baixar o provisioning profile manualmente

### Passo 4.5: Verificar o Info.plist

O `Info.plist` geralmente não precisa de alterações adicionais para o Sign In with Apple, mas verifique se está correto:

1. Abra `ios/Runner/Info.plist`
2. Verifique se o `CFBundleIdentifier` está correto
3. Não é necessário adicionar URLs schemes manualmente para Apple (diferente do Google)

---

## 5. Implementação no Código

### Passo 5.1: Adicionar Método no AuthRepository

O método `signInWithApple()` será adicionado ao `AuthRepository` seguindo o mesmo padrão do `signInWithGoogle()`.

### Passo 5.2: Adicionar Método no AppState

O método `signInWithApple()` será adicionado ao `AppState` para gerenciar o estado da autenticação.

### Passo 5.3: Atualizar a UI (LoginPage)

1. Adicionar verificação de plataforma (iOS vs Android)
2. Adicionar botão "Continuar com Apple" apenas para iOS
3. O botão deve aparecer abaixo do botão "Continuar com Google"

### Passo 5.4: Detalhes da Implementação

- **Detecção de Plataforma**: Usar `Platform.isIOS` do pacote `dart:io`
- **Botão Apple**: Seguir o design system do app, similar ao botão do Google
- **Tratamento de Erros**: Implementar tratamento adequado de erros
- **Criação de Usuário**: Criar usuário no Firestore quando for primeiro login

---

## 6. Testes

### Passo 6.1: Testar em Dispositivo Físico iOS

⚠️ **IMPORTANTE**: O Sign In with Apple **NÃO funciona no simulador**. Você **DEVE** testar em um dispositivo físico iOS.

1. Conecte um iPhone/iPad ao Mac
2. Selecione o dispositivo no Xcode
3. Execute o app (`flutter run` ou pelo Xcode)
4. Teste o fluxo de login com Apple

### Passo 6.2: Cenários de Teste

Teste os seguintes cenários:

- ✅ Login bem-sucedido com Apple
- ✅ Cancelamento do login pelo usuário
- ✅ Primeiro login (criação de conta)
- ✅ Login de usuário existente
- ✅ Verificar se o botão aparece apenas no iOS
- ✅ Verificar se o botão não aparece no Android

### Passo 6.3: Verificar no Firebase

1. Após login bem-sucedido, verifique no Firebase Console:
   - **Authentication** > **Users**: Deve aparecer um novo usuário
   - Verifique se o provedor está como "apple.com"
   - Verifique se o email foi coletado (se o usuário permitiu)

---

## 7. Troubleshooting

### Problema: "Sign In with Apple não aparece no Firebase Console"

**Solução**: 
- Certifique-se de que está usando a versão mais recente do Firebase Console
- Verifique se o projeto Firebase está configurado corretamente

### Problema: "Erro ao fazer login: Invalid client"

**Solução**:
- Verifique se o Bundle ID no Xcode corresponde ao App ID no Apple Developer Console
- Verifique se o Sign In with Apple está habilitado no App ID
- Verifique se o provisioning profile está atualizado

### Problema: "O botão não aparece no iOS"

**Solução**:
- Verifique se está usando `Platform.isIOS` corretamente
- Verifique se a capability foi adicionada no Xcode
- Limpe o build: `flutter clean` e `cd ios && pod install`

### Problema: "Erro: Sign In with Apple não está disponível"

**Solução**:
- Certifique-se de estar testando em dispositivo físico (não funciona no simulador)
- Verifique se o iOS do dispositivo é 13.0 ou superior
- Verifique se a capability está adicionada no Xcode

### Problema: "Callback URL não funciona"

**Solução**:
- Verifique se o URL foi adicionado corretamente no Services ID
- Certifique-se de que o domínio está configurado no Services ID
- Verifique se não há espaços ou caracteres especiais no URL

### Problema: "Erro ao obter credenciais"

**Solução**:
- Verifique se o Firebase está configurado corretamente
- Verifique se o `GoogleService-Info.plist` está atualizado
- Verifique os logs do Xcode para mais detalhes

---

## 📝 Checklist Final

Antes de considerar a implementação completa, verifique:

### Configurações no Firebase e Apple Developer
- [x] Firebase Console: Sign In with Apple ativado ✅
- [x] Apple Developer Console: App ID com Sign In with Apple habilitado ✅
- [ ] Apple Developer Console: Services ID criado e configurado (se necessário)
- [ ] Apple Developer Console: Domínios e URLs de retorno configurados (se Services ID criado)
- [x] Apple Developer Console: Server-to-Server Notification Endpoint configurado ✅

### Configurações no Xcode
- [x] Xcode: Capability "Sign In with Apple" adicionada ✅
- [x] Xcode: Bundle Identifier correto ✅
- [x] Xcode: Provisioning Profile atualizado ✅

### Implementação no Código
- [x] Flutter: Dependência `sign_in_with_apple` adicionada
- [x] Código: Método `signInWithApple()` implementado no AuthRepository
- [x] Código: Método `signInWithApple()` implementado no AppState
- [x] Código: Botão adicionado na UI (apenas iOS)
- [x] Código: Verificação de plataforma (iOS vs Android) implementada

### Testes
- [x] Testes: Funcionando em dispositivo físico iOS ✅
- [x] Testes: Botão não aparece no Android ✅
- [x] Firebase: Usuários sendo criados corretamente ✅

---

## 🔗 Links Úteis

- [Documentação oficial do Sign In with Apple](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Auth - Sign In with Apple](https://firebase.google.com/docs/auth/ios/apple)
- [Flutter package: sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)
- [Apple Developer Console](https://developer.apple.com/account/)
- [Firebase Console](https://console.firebase.google.com/)

---

## 📞 Suporte

Se encontrar problemas durante a implementação:

1. Verifique os logs do Xcode
2. Verifique os logs do Flutter (`flutter run -v`)
3. Consulte a documentação oficial
4. Verifique se todos os passos foram seguidos corretamente

---

**Última atualização**: Dezembro 2024

---

## ✅ Status de Implementação

**Última verificação**: Testado e funcionando em dispositivo físico iPhone ✅

- ✅ Código implementado e testado
- ✅ Firebase Console configurado
- ✅ Apple Developer Console configurado
- ✅ Xcode configurado (Capability adicionada)
- ✅ Build bem-sucedido no dispositivo físico
- ✅ Login com Apple funcionando corretamente
- ✅ Usuários sendo criados no Firebase

**Implementação 100% completa e funcional!** 🎉

