import {defineConfig} from "vitest/config";

// Testes de integração rodam contra o emulador do Firestore (emulators:exec).
export default defineConfig({
  test: {
    include: ["integration/**/*.itest.ts"],
    fileParallelism: false,
    testTimeout: 20000,
  },
});
