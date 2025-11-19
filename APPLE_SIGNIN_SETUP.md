# Configuração do Sign in with Apple

Este documento contém o passo a passo completo para configurar o Sign in with Apple no Firebase e preparar o projeto para implementação.

## Pré-requisitos

- Conta Apple Developer paga (necessária para acessar o Apple Developer Portal)
- Projeto Firebase já configurado
- Projeto Flutter com iOS configurado

## 1. Configuração no Apple Developer Portal

### 1.1 Criar um App ID

1. **Acesse o Apple Developer Portal**
   - Vá para [developer.apple.com](https://developer.apple.com)
   - Faça login com sua conta de desenvolvedor Apple

2. **Criar um App ID**
   - Vá para "Certificates, Identifiers & Profiles"
   - Clique em "Identifiers" → "+" para criar novo
   - Selecione "App IDs" e clique "Continue"
   - Escolha "App" e clique "Continue"
   - Preencha:
     - Description: Nome do seu app (ex: "Agendoo")
     - Bundle ID: Use o mesmo bundle ID do seu app Flutter (encontre em `ios/Runner.xcodeproj`)
   - Marque "Sign In with Apple" nas capabilities
   - Clique "Continue" e "Register"

### 1.2 Criar um Service ID

1. **Volte para "Identifiers"**
   - Clique "+" e selecione "Services IDs"
   - Preencha:
     - Description: Nome do serviço (ex: "Agendoo Sign In")
     - Identifier: Use o formato `com.suaempresa.agendoo.signin`

2. **Configurar o Service ID**
   - Marque "Sign In with Apple"
   - Clique "Continue" e "Register"
   - Clique no Service ID criado e configure:
     - Domains and Subdomains: Adicione `your-project-id.firebaseapp.com`
     - Return URLs: Adicione `https://your-project-id.firebaseapp.com/__/auth/handler`

### 1.3 Criar uma chave privada

1. **Vá para "Keys"**
   - Clique "+" para criar nova
   - Nome da chave: "Agendoo Sign In Key"
   - Marque "Sign In with Apple"
   - Clique "Configure" e selecione o App ID criado
   - Clique "Save" → "Continue" → "Register"

2. **Baixar a chave**
   - **IMPORTANTE**: Baixe o arquivo `.p8` - você só poderá baixá-lo uma vez!
   - Guarde este arquivo em local seguro

## 2. Configuração no Firebase Console

### 2.1 Habilitar Sign in with Apple

1. **Acesse o Firebase Console**
   - Vá para [console.firebase.google.com](https://console.firebase.google.com)
   - Selecione seu projeto Agendoo

2. **Configurar Authentication**
   - Vá para "Authentication" → "Sign-in method"
   - Clique em "Apple" para habilitar
   - Preencha os dados:
     - **Service ID**: O identifier do Service ID criado
     - **Apple Team ID**: Encontre no Apple Developer Portal (Account → Membership)
     - **Key ID**: O ID da chave criada (encontra no arquivo .p8 ou na lista de Keys)
     - **Private Key**: Cole o conteúdo do arquivo .p8 (formato PEM)

### 2.2 Configurar OAuth redirect URIs

1. **No Firebase Console**
   - Vá para "Project Settings" → "General"
   - Na seção "Your apps", clique no app iOS
   - Adicione o bundle ID correto se não estiver

## 3. Configuração no Xcode (iOS)

### 3.1 Configurar Capabilities

1. **Abrir o projeto**
   - Abra `ios/Runner.xcworkspace` no Xcode
   - Selecione o target "Runner"

2. **Adicionar capability**
   - Vá para "Signing & Capabilities"
   - Clique "+ Capability" e adicione "Sign In with Apple"

### 3.2 Verificar Bundle ID

- Certifique-se que o Bundle Identifier no Xcode corresponde ao App ID criado

## 4. Checklist de Verificação

- [ ] App ID configurado com "Sign In with Apple" habilitado
- [ ] Service ID criado e configurado com domínios corretos
- [ ] Chave privada (.p8) baixada e configurada no Firebase
- [ ] Firebase Console configurado com todos os dados
- [ ] Xcode configurado com a capability "Sign In with Apple"
- [ ] Bundle ID do Xcode corresponde ao App ID criado

## 5. Teste Básico

Após a configuração, você pode testar se está funcionando:
- No Firebase Console, vá para "Authentication" → "Users"
- Tente fazer login com Apple (quando implementado)
- Verifique se o usuário aparece na lista

## 6. Próximos Passos

Após completar todas as configurações acima:

1. Salve todas as informações importantes (IDs, chaves, etc.)
2. Informe que as configurações foram concluídas
3. A implementação do código Flutter será feita

## Informações Importantes para Guardar

- **Apple Team ID**: _______________
- **App ID**: _______________
- **Service ID**: _______________
- **Key ID**: _______________
- **Bundle ID**: _______________
- **Firebase Project ID**: _______________

---

**Nota**: Este arquivo deve ser mantido seguro e não deve ser commitado no repositório, pois contém informações sensíveis sobre configurações de autenticação.
