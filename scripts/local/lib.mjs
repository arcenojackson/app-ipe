// Utilitários compartilhados pelos scripts do ambiente local.
// Só Node padrão (sem dependências), para rodar logo após o clone.
import {spawn, spawnSync} from "node:child_process";
import {existsSync, mkdirSync, readFileSync} from "node:fs";
import os from "node:os";
import net from "node:net";
import path from "node:path";
import {fileURLToPath} from "node:url";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const isWin = process.platform === "win32";
export const LOCAL_PROJECT = "demo-ipe";
export const PORTS = {
  auth: 9099,
  firestore: 8080,
  functions: 5001,
  storage: 9199,
  hub: 4400,
  portal: 3000,
};

const color = (code) => (text) =>
  process.stdout.isTTY ? `\u001b[${code}m${text}\u001b[0m` : text;
export const c = {
  green: color(32), red: color(31), yellow: color(33), dim: color(2), bold: color(1),
};
export const ok = (msg) => console.log(`${c.green("✔")} ${msg}`);
export const warn = (msg) => console.log(`${c.yellow("⚠")} ${msg}`);
export const fail = (msg) => console.log(`${c.red("✘")} ${msg}`);
export const info = (msg) => console.log(`${c.dim("•")} ${msg}`);

export const p = (...parts) => path.join(ROOT, ...parts);

/** Executa um comando e devolve {status, stdout, stderr} (nunca lança). */
export function capture(cmd, args = [], opts = {}) {
  const res = spawnSync(cmd, args, {encoding: "utf8", shell: isWin, ...opts});
  return {
    status: res.error ? -1 : res.status,
    stdout: res.stdout ?? "",
    stderr: res.stderr ?? "",
  };
}

/** Executa com saída direta no terminal; rejeita se sair com erro. */
export function run(cmd, args = [], opts = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {stdio: "inherit", shell: isWin, ...opts});
    child.on("error", reject);
    child.on("exit", (code) =>
      code === 0 ? resolve() : reject(new Error(`${cmd} ${args.join(" ")} saiu com código ${code}`)));
  });
}

/** Inicia um processo filho de longa duração (sem esperar). */
export function start(cmd, args = [], opts = {}) {
  return spawn(cmd, args, {stdio: "inherit", shell: isWin, ...opts});
}

export function commandExists(cmd) {
  return capture(isWin ? "where" : "which", [cmd]).status === 0;
}

/** "v22.19.0" / "17.0.17" / "3.9.2" -> [22, 19, 0] */
export function parseVersion(text) {
  const m = /(\d+)\.(\d+)(?:\.(\d+))?/.exec(text ?? "");
  return m ? [Number(m[1]), Number(m[2]), Number(m[3] ?? 0)] : null;
}

export function versionAtLeast(found, min) {
  for (let i = 0; i < 3; i++) {
    if ((found[i] ?? 0) !== (min[i] ?? 0)) return (found[i] ?? 0) > (min[i] ?? 0);
  }
  return true;
}

export function javaMajor() {
  const res = capture("java", ["-version"]);
  if (res.status !== 0) return null;
  const out = `${res.stderr}\n${res.stdout}`;
  const m = /version "(\d+)(?:\.(\d+))?/.exec(out);
  if (!m) return null;
  // Java 8 aparece como "1.8".
  return m[1] === "1" ? Number(m[2]) : Number(m[1]);
}

export function flutterInfo() {
  if (!commandExists("flutter")) return null;
  const res = capture("flutter", ["--version", "--machine"]);
  if (res.status !== 0) return {flutter: null, dart: null};
  const start = res.stdout.indexOf("{");
  try {
    const json = JSON.parse(res.stdout.slice(start));
    return {flutter: json.frameworkVersion, dart: json.dartSdkVersion};
  } catch {
    return {flutter: null, dart: null};
  }
}

export function portInUse(port) {
  return new Promise((resolve) => {
    const server = net.createServer();
    server.once("error", () => resolve(true));
    server.once("listening", () => server.close(() => resolve(false)));
    server.listen(port, "127.0.0.1");
  });
}

export function waitForPort(port, timeoutMs = 120_000) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const attempt = () => {
      const socket = net.connect(port, "127.0.0.1");
      socket.once("connect", () => {
        socket.destroy();
        resolve();
      });
      socket.once("error", () => {
        socket.destroy();
        if (Date.now() - started > timeoutMs) reject(new Error(`porta ${port} não abriu`));
        else setTimeout(attempt, 500);
      });
    };
    attempt();
  });
}

/** Caminho do executável JS de um pacote npm (sem depender de .cmd no Windows). */
export function packageBin(pkgDir, binName) {
  const pkgJson = JSON.parse(readFileSync(path.join(pkgDir, "package.json"), "utf8"));
  const bin = typeof pkgJson.bin === "string" ? pkgJson.bin : pkgJson.bin?.[binName];
  if (!bin) throw new Error(`bin "${binName}" não encontrado em ${pkgDir}`);
  return path.join(pkgDir, bin);
}

export function firebaseBin() {
  const dir = p("node_modules", "firebase-tools");
  if (!existsSync(dir)) {
    throw new Error("firebase-tools não instalado. Rode `npm run setup` primeiro.");
  }
  return packageBin(dir, "firebase");
}

export function tsxBin() {
  const dir = p("functions", "node_modules", "tsx");
  if (!existsSync(dir)) {
    throw new Error("Dependências de functions/ ausentes. Rode `npm run setup` primeiro.");
  }
  return packageBin(dir, "tsx");
}

/** Ambiente seguro para falar com os emuladores: sem credenciais reais. */
export function emulatorEnv(extra = {}) {
  const env = {...process.env, ...extra};
  delete env.GOOGLE_APPLICATION_CREDENTIALS;
  delete env.FIREBASE_TOKEN;
  // Aponta o gcloud para uma pasta vazia: mesmo quem tem `gcloud auth
  // application-default login` feito não expõe credenciais reais aos
  // emuladores (as Functions só enxergam o projeto demo-ipe).
  const emptyGcloud = path.join(os.tmpdir(), "ipe-empty-gcloud-config");
  mkdirSync(emptyGcloud, {recursive: true});
  env.CLOUDSDK_CONFIG = emptyGcloud;
  env.GCLOUD_PROJECT = LOCAL_PROJECT;
  env.FIRESTORE_EMULATOR_HOST = `127.0.0.1:${PORTS.firestore}`;
  env.FIREBASE_AUTH_EMULATOR_HOST = `127.0.0.1:${PORTS.auth}`;
  env.FIREBASE_STORAGE_EMULATOR_HOST = `127.0.0.1:${PORTS.storage}`;
  return env;
}

export function installHint(tool) {
  const hints = {
    node: isWin
      ? "winget install OpenJS.NodeJS.LTS   (ou https://nodejs.org)"
      : "brew install node@22   (ou https://nodejs.org)",
    java: isWin
      ? "winget install EclipseAdoptium.Temurin.21.JDK"
      : "brew install --cask temurin@21",
    flutter: "https://docs.flutter.dev/get-started/install (escolha seu sistema; precisa de Dart 3.9.2+)",
  };
  return hints[tool];
}
