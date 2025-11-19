# 🔍 Verificação da Configuração do Firebase

## ✅ Para fazer login com usuários existentes, verifique:

### 1. **Firebase Console - Authentication**

1. Acesse [console.firebase.google.com](https://console.firebase.google.com)
2. Selecione o projeto `agendoo-45bf9`
3. Vá para **Authentication** → **Sign-in method**
4. **Verifique se "Email/Password" está habilitado** ✅

### 2. **Firebase Console - Firestore Database**

1. Vá para **Firestore Database**
2. **Verifique se o banco está criado** ✅
3. **Configure as regras de segurança**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Usuários podem ler/escrever apenas seus próprios dados
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Regras para agendamentos
    match /appointments/{appointmentId} {
      allow read, write: if request.auth != null;
    }
    
    // Regras para serviços
    match /services/{serviceId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. **Teste de Login**

1. **Execute o app**: `flutter run`
2. **Tente fazer login** com um usuário existente
3. **Verifique no console** se há erros

### 4. **Possíveis Problemas e Soluções**

#### ❌ Erro: "User not found"
- **Causa**: Usuário não existe no Firebase Auth
- **Solução**: Crie o usuário primeiro no Firebase Console ou use o registro

#### ❌ Erro: "Invalid email/password"
- **Causa**: Credenciais incorretas
- **Solução**: Verifique email e senha

#### ❌ Erro: "Permission denied"
- **Causa**: Regras do Firestore muito restritivas
- **Solução**: Configure as regras acima

#### ❌ Erro: "Network error"
- **Causa**: Problema de conectividade
- **Solução**: Verifique a conexão com a internet

### 5. **Debug e Logs**

Para ver logs detalhados, adicione no `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Habilitar logs do Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Logs para debug
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    print('Auth state changed: ${user?.email}');
  });
  
  runApp(const MyApp());
}
```

### 6. **Verificação Final**

✅ **Firebase CLI**: `firebase --version`  
✅ **FlutterFire**: `flutterfire --version`  
✅ **Dependências**: `flutter pub get`  
✅ **Compilação**: `flutter build apk --debug`  
✅ **Authentication habilitado** no console  
✅ **Firestore criado** e regras configuradas  
✅ **App executando** sem erros  

## 🚀 Se tudo estiver OK:

1. **Execute**: `flutter run`
2. **Teste login** com usuário existente
3. **Verifique** se os dados aparecem no Firestore
4. **Teste registro** de novo usuário

## 📞 Se ainda houver problemas:

1. Verifique os logs no console do Flutter
2. Verifique os logs no Firebase Console
3. Teste com um usuário recém-criado
4. Verifique se as regras do Firestore estão corretas
