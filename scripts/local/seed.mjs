// Popula os emuladores (que já precisam estar no ar) com dados de teste.
// Uso: npm run seed
import {emulatorEnv, p, run, tsxBin} from "./lib.mjs";

export async function seed() {
  await run(process.execPath, [tsxBin(), "scripts/seed-local.ts"], {
    cwd: p("functions"),
    env: emulatorEnv(),
  });
}

if (process.argv[1]?.endsWith("seed.mjs")) {
  await seed();
}
