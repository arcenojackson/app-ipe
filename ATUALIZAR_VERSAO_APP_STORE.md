# 📱 Atualizar Versão - Apple App Store

Guia rápido para publicar uma nova versão do app na App Store.

---

## 📋 Passos Rápidos

### 1. Atualizar Versão no `pubspec.yaml`

Edite o arquivo `pubspec.yaml` e incremente a versão:

```yaml
version: 1.0.5+9  # Incremente ambos os números (versão + build number)
```

**Importante:**
- O número após o `+` (build number) **deve sempre aumentar** (9 → 10 → 11...)
- O número antes do `+` é a versão visível para o usuário (1.0.4 → 1.0.5 → 1.1.0...)

### 2. Preparar Build

No terminal, execute:

```bash
cd /Users/arcenojackson/www/app_ipe/ipe_flutter
flutter clean
flutter pub get
flutter build ios --release
```

### 3. Arquivar no Xcode

1. Abra o projeto no Xcode:
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. No Xcode:
   - Selecione **"Any iOS Device"** como destino (não um simulador)
   - Vá em **Product** → **Archive**
   - Aguarde o processo completar

### 4. Upload para App Store Connect

Após o arquivamento:

1. A janela **Organizer** abrirá automaticamente
2. Selecione o archive recém-criado
3. Clique em **"Distribute App"**
4. Selecione **"App Store Connect"** → **Next**
5. Selecione **"Upload"** → **Next**
6. Revise as opções (deixe os padrões) → **Next**
7. Selecione sua equipe → **Next**
8. Revise e clique em **"Upload"**

### 5. Completar Informações no App Store Connect

1. Acesse [App Store Connect](https://appstoreconnect.apple.com)
2. Vá em **"Meus Apps"** → Selecione **"App IPE"**
3. Clique em **"Versão iOS"** (ou crie uma nova versão)
4. Após o build ser processado (15 min - 2h):
   - Selecione o build na seção **"Build"**
   - Atualize **"Sobre esta versão"** (o que mudou)
   - Revise outras informações se necessário

### 6. Enviar para Revisão

1. Role até o final da página
2. Clique em **"Adicionar para revisão"** ou **"Enviar para revisão"**
3. Confirme a submissão

### 7. Aguardar Aprovação

- **Tempo**: 24-48 horas (geralmente)
- Você receberá emails sobre o status
- Após aprovação, o app será publicado automaticamente

---

## ⚠️ Lembrete Importante

- **Certifique-se que a assinatura está correta** no Xcode (Signing & Capabilities)
- **Nunca reutilize o mesmo build number** - sempre incremente
- O build pode levar até 2 horas para aparecer no App Store Connect

---

## 🔗 Links Úteis

- [App Store Connect](https://appstoreconnect.apple.com)
- [Apple Developer](https://developer.apple.com)

