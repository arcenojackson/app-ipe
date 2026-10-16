module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
    "/test/**/*", // Testes rodam no Vitest, fora do tsconfig de build.
    "/scripts/**/*", // Scripts manuais de manutenção.
    "/vitest.config.ts", // Config do Vitest, fora do tsconfig de build.
    "/vitest.emulator.config.ts", // Config dos testes de emulador.
    "/test-emulator/**/*", // Testes de emulador, fora do tsconfig de build.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
  },
  overrides: [
    {
      // Código novo da biblioteca: comentários curtos em vez de JSDoc completo.
      files: ["src/teaching/library/**/*.ts"],
      rules: {
        "require-jsdoc": "off",
        "valid-jsdoc": "off",
      },
    },
  ],
};
