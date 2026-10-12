import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const root = resolve(import.meta.dirname, "..");

export async function createEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: "demo-ipe-rules",
    firestore: {rules: readFileSync(resolve(root, "firestore.rules"), "utf8")},
    storage: {rules: readFileSync(resolve(root, "storage.rules"), "utf8")},
  });
}
