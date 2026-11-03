import {Suspense} from "react";
import {LoginForm} from "@/core/auth/LoginForm";

// useSearchParams (destino pós-login) exige Suspense com cacheComponents.
export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
        <LoginForm />
      </Suspense>
    </main>
  );
}
