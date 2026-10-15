import {defineConfig} from "vitest/config";

// Os arquivos de teste compartilham os mesmos emuladores (Firestore/Storage);
// rodar em paralelo faz um ambiente limpar as regras do outro.
export default defineConfig({
  test: {fileParallelism: false},
});
