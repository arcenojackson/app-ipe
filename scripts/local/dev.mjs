// Sobe o ambiente local: Functions (build + watch), emuladores Firebase
// (Auth, Firestore, Storage, Functions), dados de teste e, opcionalmente, o
// portal web.
// Uso: npm run dev                  (dados resetam a cada execução)
//      npm run dev -- --portal      (também inicia o portal em :3000)
//      npm run dev:persist          (guarda/restaura dados em .emulator-data/)
import {existsSync} from "node:fs";
import {
  LOCAL_PROJECT, PORTS, c, emulatorEnv, fail, firebaseBin, info, ok, p, portInUse, run,
  start, waitForPort,
} from "./lib.mjs";
import {javaMajor} from "./lib.mjs";
import {seed} from "./seed.mjs";

const withPortal = process.argv.includes("--portal");
const persist = process.argv.includes("--persist");
const dataDir = p(".emulator-data");

const java = javaMajor();
if (java === null || java < 21) {
  fail(`JDK 21+ é obrigatório para os emuladores (encontrado: ${java ?? "nenhum"}). Rode \`npm run doctor\`.`);
  process.exit(1);
}
if (!existsSync(p("node_modules", "firebase-tools")) || !existsSync(p("functions", "node_modules"))) {
  fail("Dependências ausentes. Rode `npm run setup` primeiro.");
  process.exit(1);
}
for (const [name, port] of Object.entries({auth: PORTS.auth, firestore: PORTS.firestore, functions: PORTS.functions, storage: PORTS.storage})) {
  if (await portInUse(port)) {
    fail(`Porta ${port} (${name}) já está em uso. Pare o processo que a usa (outro emulador?) e tente de novo.`);
    process.exit(1);
  }
}

const children = [];
const shutdown = () => {
  for (const child of children) child.kill();
  setTimeout(() => process.exit(0), 500);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

console.log(c.bold("Compilando Functions..."));
await run("npm", ["run", "build"], {cwd: p("functions")});
children.push(start("npm", ["run", "build:watch"], {cwd: p("functions"), stdio: "ignore"}));

const hasSavedData = persist && existsSync(dataDir);
const emulatorArgs = [
  firebaseBin(), "emulators:start",
  "--only", "auth,firestore,storage,functions",
  "--project", LOCAL_PROJECT,
  ...(persist ? ["--import", dataDir, "--export-on-exit", dataDir] : []),
];
console.log(c.bold("\nIniciando emuladores..."));
children.push(start(process.execPath, emulatorArgs, {cwd: p(), env: emulatorEnv()}));

await Promise.all([waitForPort(PORTS.firestore), waitForPort(PORTS.auth)]);
await waitForPort(PORTS.functions);

if (hasSavedData) {
  info("Dados restaurados de .emulator-data/ (seed ignorado). Apague a pasta para recomeçar.");
} else {
  await seed();
}

if (withPortal) {
  console.log(c.bold("\nIniciando portal web..."));
  children.push(start("npm", ["run", "dev"], {cwd: p("web-portal")}));
}

ok("Ambiente local no ar. Ctrl+C para encerrar.");
console.log(`
  Emulator Hub : http://127.0.0.1:${PORTS.hub}
  Auth         : 127.0.0.1:${PORTS.auth}
  Firestore    : 127.0.0.1:${PORTS.firestore}
  Functions    : 127.0.0.1:${PORTS.functions}
  Storage      : 127.0.0.1:${PORTS.storage}
  ${withPortal ? `Portal       : http://localhost:${PORTS.portal}` : "Portal       : npm run dev -- --portal (ou: cd web-portal && npm run dev)"}

  App Flutter  : npm run app          (em outro terminal)
  Contas       : admin@ipe.test | curador@ipe.test | professor@ipe.test | membro@ipe.test
  Senha        : senha123
`);

await new Promise(() => {});
