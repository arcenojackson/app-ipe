import * as admin from "firebase-admin";

export const PROD_PROJECT_ID = "app-ipe";
export const LOCAL_PROJECT_ID = "demo-ipe";

export interface ScriptTarget {
  readonly local: boolean;
  readonly projectId: string;
}

/**
 * Decide onde um script de manutenção pode escrever, ANTES de qualquer
 * conexão. Por padrão só roda contra os emuladores (FIRESTORE_EMULATOR_HOST
 * definido). Para atingir produção é preciso passar `--prod` de forma
 * explícita; sem isso o processo aborta.
 * @param {string[]} argv - process.argv do script
 * @return {ScriptTarget} alvo escolhido
 */
export function resolveTarget(argv: string[]): ScriptTarget {
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    return {
      local: true,
      projectId: process.env.GCLOUD_PROJECT ?? LOCAL_PROJECT_ID,
    };
  }
  if (argv.includes("--prod")) {
    return {local: false, projectId: PROD_PROJECT_ID};
  }
  console.error(
    "Abortado: nenhum emulador detectado (FIRESTORE_EMULATOR_HOST vazio).\n" +
    "- Para o ambiente local, suba os emuladores e rode com o env do " +
    "emulador (veja docs/DESENVOLVIMENTO_LOCAL.md).\n" +
    "- Para PRODUÇÃO (somente mantenedores), repita o comando com --prod."
  );
  process.exit(1);
}

/**
 * Inicializa o Admin SDK no alvo resolvido e avisa qual é.
 * @param {string[]} argv - process.argv do script
 * @param {admin.AppOptions} extra - opções adicionais (ex.: storageBucket)
 * @return {ScriptTarget} alvo escolhido
 */
export function initScriptApp(
  argv: string[],
  extra: admin.AppOptions = {}
): ScriptTarget {
  const target = resolveTarget(argv);
  admin.initializeApp({projectId: target.projectId, ...extra});
  console.log(
    target.local ?
      `Alvo: EMULADOR local (${target.projectId})` :
      `Alvo: PRODUÇÃO (${target.projectId})`
  );
  return target;
}
