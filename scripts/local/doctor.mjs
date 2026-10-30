// Verifica se a máquina está pronta para o ambiente local.
// Uso: npm run doctor            (texto)
//      npm run doctor -- --json  (saída estruturada, boa para IAs)
import {existsSync, readFileSync} from "node:fs";
import {
  PORTS, c, capture, commandExists, fail, flutterInfo, info, installHint, javaMajor,
  ok, p, parseVersion, portInUse, versionAtLeast, warn,
} from "./lib.mjs";

const asJson = process.argv.includes("--json");
export async function runDoctor() {
  const results = [];
  const add = (id, level, message, fix) => results.push({id, level, message, fix});

  // Node
  const nodeV = parseVersion(process.version);
  if (versionAtLeast(nodeV, [22, 0, 0])) add("node", "ok", `Node ${process.version}`);
  else add("node", "error", `Node ${process.version} (precisa 22+)`, installHint("node"));

  // Java (exigido pelo Firebase CLI 15 para Firestore/Storage emulados)
  const java = javaMajor();
  if (java === null) add("java", "error", "Java não encontrado (precisa JDK 21+)", installHint("java"));
  else if (java < 21) add("java", "error", `Java ${java} (precisa JDK 21+; o Firebase CLI 15 recusa versões menores)`, installHint("java"));
  else add("java", "ok", `Java ${java}`);

  // Flutter / Dart
  const fl = flutterInfo();
  if (!fl) add("flutter", "error", "Flutter não encontrado no PATH", installHint("flutter"));
  else if (!fl.dart) add("flutter", "warn", "Flutter encontrado, mas `flutter --version` falhou");
  else if (!versionAtLeast(parseVersion(fl.dart), [3, 9, 2])) {
    add("flutter", "error", `Dart ${fl.dart} (precisa 3.9.2+; Flutter ${fl.flutter})`, "flutter upgrade");
  } else add("flutter", "ok", `Flutter ${fl.flutter} (Dart ${fl.dart})`);

  if (commandExists("git")) add("git", "ok", "git");
  else add("git", "warn", "git não encontrado");

  // Credenciais reais soltas no ambiente
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    add("adc", "warn", "GOOGLE_APPLICATION_CREDENTIALS está definida: os scripts locais a ignoram, mas outros comandos podem usá-la. Evite rodar o ambiente local nesse terminal.");
  }
  if (process.env.FIREBASE_TOKEN) add("firebase-token", "warn", "FIREBASE_TOKEN definida: remova para o desenvolvimento local.");

  // Arquivos locais
  const opts = readIfExists(p("lib", "firebase_options.dart"));
  if (opts === null) add("firebase_options", "info", "lib/firebase_options.dart ausente (o `npm run setup` cria)");
  else if (/LocalFirebaseOptions/.test(opts)) add("firebase_options", "ok", "firebase_options.dart é o stub local (demo-ipe)");
  else add("firebase_options", "warn", "firebase_options.dart parece ser de PRODUÇÃO. Tudo bem: `npm run app` usa as opções locais embutidas (USE_EMULATOR). Nunca rode o app sem a flag enquanto testa.");

  // Dependências instaladas
  for (const [dir, label] of [["node_modules", "raiz"], ["functions/node_modules", "functions"], ["web-portal/node_modules", "web-portal"]]) {
    if (existsSync(p(dir))) add(`deps-${label}`, "ok", `dependências: ${label}`);
    else add(`deps-${label}`, "info", `dependências de ${label} não instaladas (o \`npm run setup\` instala)`);
  }

  // Portas
  const busy = [];
  for (const [name, port] of Object.entries(PORTS)) if (await portInUse(port)) busy.push(`${name}:${port}`);
  if (busy.length) add("ports", "info", `Portas em uso: ${busy.join(", ")} (ok se forem os emuladores já rodando; senão libere-as)`);
  else add("ports", "ok", "Portas dos emuladores livres");

  return results;
}

function readIfExists(file) {
  return existsSync(file) ? readFileSync(file, "utf8") : null;
}

export function report(list) {
  if (asJson) {
    console.log(JSON.stringify({ready: !list.some((r) => r.level === "error"), checks: list}, null, 2));
    return;
  }
  for (const r of list) {
    const line = r.fix ? `${r.message}\n    como resolver: ${r.fix}` : r.message;
    if (r.level === "ok") ok(line);
    else if (r.level === "error") fail(line);
    else if (r.level === "warn") warn(line);
    else info(line);
  }
  const errors = list.filter((r) => r.level === "error");
  console.log(errors.length
    ? `\n${c.red(`${errors.length} pendência(s) obrigatória(s).`)} Resolva e rode \`npm run doctor\` de novo.`
    : `\n${c.green("Máquina pronta.")}`);
}

if (process.argv[1]?.endsWith("doctor.mjs")) {
  const list = await runDoctor();
  report(list);
  process.exit(list.some((r) => r.level === "error") ? 1 : 0);
}
