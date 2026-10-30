// Prepara uma máquina zerada: verifica pré-requisitos, instala dependências e
// cria os arquivos de configuração LOCAL (nunca sobrescreve nada existente).
// Uso: npm run setup
import {copyFileSync, existsSync, mkdirSync} from "node:fs";
import path from "node:path";
import {report, runDoctor} from "./doctor.mjs";
import {c, info, ok, p, run, warn} from "./lib.mjs";

console.log(c.bold("App IPE — preparação do ambiente local\n"));

const checks = await runDoctor();
const required = ["node", "java", "flutter"];
const blocking = checks.filter((r) => r.level === "error" && required.includes(r.id));
report(checks.filter((r) => ["node", "java", "flutter", "git", "adc", "firebase-token"].includes(r.id)));
if (blocking.length) {
  console.log("\nInstale o que falta e rode `npm run setup` novamente.");
  process.exit(1);
}

console.log(`\n${c.bold("1/4 Dependências")}`);
await run("npm", ["install", "--no-audit", "--no-fund"], {cwd: p()});
await run("npm", ["install", "--no-audit", "--no-fund"], {cwd: p("functions")});
await run("npm", ["install", "--no-audit", "--no-fund"], {cwd: p("web-portal")});
await run("flutter", ["pub", "get"], {cwd: p()});

console.log(`\n${c.bold("2/4 Build das Functions")}`);
await run("npm", ["run", "build"], {cwd: p("functions")});

console.log(`\n${c.bold("3/4 Arquivos de configuração local")}`);
const files = [
  // [origem, destino]
  ["scripts/local/templates/firebase_options.dart", "lib/firebase_options.dart"],
  ["scripts/local/templates/google-services.json", "android/app/google-services.json"],
  ["scripts/local/templates/GoogleService-Info.plist", "ios/Runner/GoogleService-Info.plist"],
  ["lib/src/core/config/app_secrets.dart.example", "lib/src/core/config/app_secrets.dart"],
  ["web-portal/.env.local.example", "web-portal/.env.local"],
];
for (const [from, to] of files) {
  if (existsSync(p(to))) {
    info(`${to} já existe — mantido`);
    continue;
  }
  mkdirSync(path.dirname(p(to)), {recursive: true});
  copyFileSync(p(from), p(to));
  ok(`${to} criado`);
}

console.log(`\n${c.bold("4/4 Conferência")}`);
const after = await runDoctor();
report(after.filter((r) => ["firebase_options", "ports"].includes(r.id)));
warn("Chaves opcionais: YouTube (busca de vídeos) e Pexels (imagens) ficam desligadas no ambiente local.");

console.log(`
${c.green("Pronto!")} Para desenvolver:
  1. ${c.bold("npm run dev")}            sobe os emuladores e popula dados de teste
  2. ${c.bold("npm run app")}            (outro terminal) roda o app Flutter no Chrome
  3. ${c.bold("npm run dev -- --portal")} (opcional) inclui o portal web em http://localhost:3000

Contas de teste (senha senha123): admin@ipe.test, curador@ipe.test,
professor@ipe.test, membro@ipe.test. Guia completo: docs/DESENVOLVIMENTO_LOCAL.md`);
