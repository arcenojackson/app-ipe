# Instruções para Preencher Privacidade no App Store Connect

## 📋 Checklist Rápido

- [ ] Criar URL da Política de Privacidade
- [ ] Preencher questionário "Começar"
- [ ] Adicionar URL no campo obrigatório
- [ ] Salvar alterações

---

## 🔗 Criar URL da Política (5 minutos)

### Opção 1: GitHub Pages (Recomendado)

1. Acesse [github.com](https://github.com)
2. Crie um novo repositório (ex: `app-ipe-privacy`)
3. Faça upload do arquivo `POLITICA_PRIVACIDADE.md`
4. Vá em **Settings** → **Pages**
5. Selecione **Source**: `main` branch
6. Clique **Save**
7. Aguarde alguns minutos
8. A URL será: `https://seu-usuario.github.io/app-ipe-privacy/POLITICA_PRIVACIDADE.md`

### Opção 2: Google Sites

1. Acesse [sites.google.com](https://sites.google.com)
2. Clique **Criar** → **Novo site**
3. Cole o conteúdo de `POLITICA_PRIVACIDADE.md`
4. Publique o site
5. Use a URL gerada

---

## ✅ Como Responder o Questionário

### Passo 1: Dados Coletados

**Email (Email Address)**
- ✅ Sim, coletamos
- Finalidade: **App Functionality**
- Rastreamento: **Não**
- Compartilhado: **Sim** (com Google/Firebase para autenticação)

**Nome (Name)**
- ✅ Sim, coletamos
- Finalidade: **App Functionality**
- Rastreamento: **Não**
- Compartilhado: **Não**

**User ID**
- ✅ Sim, coletamos
- Finalidade: **App Functionality**
- Rastreamento: **Não**
- Compartilhado: **Sim** (com Google/Firebase)

**Product Interaction (Analytics)**
- ✅ Sim, coletamos
- Finalidade: **Analytics**
- Rastreamento: **Não**
- Compartilhado: **Sim** (com Google/Firebase Analytics)

**Crash Data (Diagnostics)**
- ✅ Sim, coletamos
- Finalidade: **Crash Reports** ou **Analytics**
- Rastreamento: **Não**
- Compartilhado: **Sim** (com Google/Firebase Crashlytics)

### Passo 2: Compartilhamento

Quando perguntar "Compartilhamos com terceiros?":
- ✅ **Sim**
- Especificar: **Google/Firebase** (para autenticação, analytics, crashlytics, armazenamento)

### Passo 3: Localização

- **Não coletamos localização**

---

## 📝 Resumo das Respostas

| Dado | Coletamos? | Finalidade | Rastreamento | Compartilhado |
|------|-----------|------------|--------------|---------------|
| Email | ✅ Sim | App Functionality | ❌ Não | ✅ Sim (Google) |
| Nome | ✅ Sim | App Functionality | ❌ Não | ❌ Não |
| User ID | ✅ Sim | App Functionality | ❌ Não | ✅ Sim (Google) |
| Analytics | ✅ Sim | Analytics | ❌ Não | ✅ Sim (Google) |
| Crash Data | ✅ Sim | Diagnostics | ❌ Não | ✅ Sim (Google) |
| Localização | ❌ Não | - | - | - |

---

## ⚠️ Importante

- Seja honesto nas respostas
- Se não tiver certeza, escolha "Sim" e seja conservador
- Você pode atualizar essas informações depois se necessário

---

Depois de preencher tudo, volte e adicione a URL da política de privacidade!

