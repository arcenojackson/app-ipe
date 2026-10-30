// Verifica se a máquina está pronta para o ambiente local.
// Uso: npm run doctor            (texto)
//      npm run doctor -- --json  (saída estruturada, boa para IAs)
//      npm run doctor -- --native (também confere Android/iOS: SDK, Xcode, emuladores)
import {existsSync, readFileSync} from "node:fs";
import {
  PORTS, c, capture, commandExists, fail, flutterInfo, info, installHint, javaMajor,
  ok, p, parseVersion, portInUse, versionAtLeast, warn,
} from "./lib.mjs";

const asJson = process.argv.includes("--json");
const withNative = process.argv.includes("--native");
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

  if (withNative) checkNative(add, fl);

  return results;
}

/** Confere o que falta para rodar em emulador Android / simulador iOS. */
function checkNative(add, fl) {
  if (!fl) return;
  const doctor = capture("flutter", ["doctor"]).stdout;
  const line = (re) => doctor.split("\n").find((l) => re.test(l));
  const status = (l) => (l?.includes("[✓]") ? "ok" : l?.includes("[!]") ? "warn" : "error");

  const android = line(/Android toolchain/);
  if (!android) add("android", "warn", "Android toolchain não reportado pelo `flutter doctor`", "Instale o Android Studio: https://developer.android.com/studio");
  else if (status(android) === "ok") add("android", "ok", "Android toolchain pronta");
  else add("android", "warn", "Android toolchain incompleta (veja `flutter doctor -v`)", "Abra o Android Studio uma vez (baixa o SDK) e rode `flutter doctor --android-licenses`");

  if (process.platform === "darwin") {
    const xcode = line(/Xcode - develop for iOS/);
    if (xcode && status(xcode) === "ok") add("xcode", "ok", "Xcode pronto");
    else add("xcode", "warn", "Xcode incompleto ou ausente (só necessário para iOS)", "Instale o Xcode pela App Store, depois: sudo xcode-select --switch /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch");
    if (commandExists("pod")) add("cocoapods", "ok", "CocoaPods");
    else add("cocoapods", "warn", "CocoaPods ausente (necessário para iOS)", "brew install cocoapods");
  } else {
    add("xcode", "info", "iOS só roda em macOS; neste sistema use Chrome ou Android");
  }

  const emus = capture("flutter", ["emulators"]).stdout.split("\n").filter((l) => / • /.test(l) && !/^Id /.test(l));
  if (emus.length) add("emulators", "ok", `Emuladores/simuladores disponíveis:\n      ${emus.map((l) => l.trim()).join("\n      ")}`);
  else add("emulators", "warn", "Nenhum emulador criado", "Android: Android Studio → Device Manager → Create Device. iOS: abra o Xcode → Settings → Platforms e baixe um runtime");

  const devices = capture("flutter", ["devices", "--machine"]).stdout;
  try {
    const list = JSON.parse(devices).filter((d) => d.targetPlatform?.startsWith("android") || d.targetPlatform === "ios");
    if (list.length) add("devices", "ok", `Dispositivos prontos agora: ${list.map((d) => `${d.name} (-d ${d.id})`).join(", ")}`);
    else add("devices", "info", "Nenhum emulador/simulador ligado agora. Ligue um (veja docs/DESENVOLVIMENTO_LOCAL.md, seção 'Emulador Android e simulador iOS').");
  } catch {
    add("devices", "info", "Não foi possível listar dispositivos (`flutter devices`)");
  }
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
