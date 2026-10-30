---
description: Configura o ambiente local do App IPE (emuladores, sem produção) e valida que está funcionando
---

Configure o ambiente de desenvolvimento local deste repositório **sem tocar na produção**.

1. Leia o `AGENTS.md` da raiz, em especial as "Regras invioláveis" e o "Playbook". Siga-os à risca: nada de `firebase login`, `firebase deploy`, `flutterfire configure`, chaves ou arquivos de produção.
2. Rode `npm run doctor -- --json` e interprete o resultado. Se faltar algo (Node 22+, JDK 21+, Flutter/Dart 3.9.2+), mostre ao usuário o que falta e o comando de instalação do sistema dele, e **peça confirmação antes de instalar qualquer software**. Depois de instalar, peça para abrir um terminal novo.
3. Rode `npm run setup` e confirme que terminou com "Pronto!".
4. Suba `npm run dev` em segundo plano e aguarde "Ambiente local no ar". Em seguida valide: login com `admin@ipe.test` / `senha123` funciona e o app (`npm run app`) mostra 3 cultos na Agenda.
5. Resuma ao usuário: o que foi instalado/criado, como subir e derrubar o ambiente no dia a dia (`npm run dev`, `npm run app`) e as limitações locais (sem push, sem login Google/Apple, sem funções agendadas).

Se qualquer passo exigir quebrar uma regra inviolável, pare e pergunte.
