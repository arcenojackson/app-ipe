# 📱 Atualizar Versão - Google Play Store

Guia rápido para publicar uma nova versão do app na Play Store.

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

### 2. Gerar App Bundle

No terminal, execute:

```bash
cd /Users/arcenojackson/www/app_ipe/ipe_flutter
flutter clean
flutter pub get
flutter build appbundle --release
```

O arquivo será gerado em: `build/app/outputs/bundle/release/app-release.aab`

### 3. Upload no Play Console

1. Acesse [Google Play Console](https://play.google.com/console)
2. Selecione o app **IPE**
3. Vá em **"Produção"** (ou **"Teste fechado"** se quiser testar antes)
4. Clique em **"Criar nova versão"**
5. Faça upload do arquivo: `build/app/outputs/bundle/release/app-release.aab`
6. Adicione **Notas da versão** (o que mudou nesta versão)
7. Clique em **"Salvar"**

### 4. Enviar para Revisão

1. Clique em **"Revisar versão"**
2. Revise as informações
3. Clique em **"Iniciar lançamento para produção"**
4. Confirme o envio

### 5. Aguardar Aprovação

- **Tempo**: 1-3 dias úteis (geralmente)
- Você receberá emails sobre o status
- Após aprovação, o app será atualizado automaticamente

---

## ⚠️ Lembrete Importante

- **Sempre use a mesma keystore!** O arquivo `key.properties` deve estar configurado
- **Nunca reutilize o mesmo build number** - sempre incremente
- Se houver erros, verifique se a keystore está correta

---

## 🔗 Links Úteis

- [Google Play Console](https://play.google.com/console)
- Arquivo gerado: `build/app/outputs/bundle/release/app-release.aab`

