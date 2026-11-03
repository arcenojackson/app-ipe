# Publicação: votação da eleição dentro do app

Ordem recomendada (exclusivo dos mantenedores). Design em
`docs/superpowers/specs/2026-11-02-election-voting-in-app-design.md`.

1. **Antes do app novo estar nas lojas** (retrocompatível com a web e com o app antigo):
   - `firebase deploy --only firestore:rules` (nova regra `users/{uid}/election_invites`).
   - `firebase deploy --only functions:electionCheckIn` (aceita `memberOnly`; sem o parâmetro tudo segue como antes).
2. **Publicar o app** nas lojas (skill `release-church-hub`; nova versão com o leitor de QR, permissão de câmera e as telas de voto).
3. **Só depois** que a versão nova estiver disponível nas lojas:
   - `firebase deploy --only functions:electionOpened` — o gatilho que grava os convites e manda o push de "Eleição aberta" ao abrir a eleição.

> Sempre use `--only <função>`: um deploy geral de Functions publicaria `electionOpened`
> antes da hora e avisaria membros que ainda estão com o app antigo (o texto do push já
> pede para atualizar o app, mas é melhor não depender disso).

A página `/votar/{id}` da web continua funcionando como plano B para quem não atualizou o app.
