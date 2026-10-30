// Roda o app Flutter apontando para os emuladores locais.
// Uso: npm run app                    (Chrome)
//      npm run app -- -d emulator-5554   (emulador Android)
//      npm run app -- -d ios             (simulador iOS, só macOS)
// Argumentos extras são repassados ao `flutter run`.
import {p, run} from "./lib.mjs";

const args = process.argv.slice(2);
const deviceIdx = args.findIndex((a) => a === "-d" || a === "--device-id");
const device = deviceIdx >= 0 ? args[deviceIdx + 1] : "chrome";
const rest = deviceIdx >= 0 ? args.filter((_, i) => i !== deviceIdx && i !== deviceIdx + 1) : args;

// Emulador Android enxerga a máquina host em 10.0.2.2; as demais, em 127.0.0.1.
const isAndroidEmulator = /^emulator-/.test(device);
const portalHost = isAndroidEmulator ? "10.0.2.2" : "localhost";

const defines = [
  "--dart-define=USE_EMULATOR=true",
  `--dart-define=PORTAL_BASE_URL=http://${portalHost}:3000`,
];
if (process.env.EMULATOR_HOST) defines.push(`--dart-define=EMULATOR_HOST=${process.env.EMULATOR_HOST}`);
if (process.env.PEXELS_API_KEY) defines.push(`--dart-define=PEXELS_API_KEY=${process.env.PEXELS_API_KEY}`);

await run("flutter", ["run", "-d", device, ...defines, ...rest], {cwd: p()});
