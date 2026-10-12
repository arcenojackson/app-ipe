import type {Metadata} from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Portal de Ensino IPE",
  description: "Materiais, bibliografia e fórum para os professores da IPE.",
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return (
    <html lang="pt-BR">
      <body className="min-h-screen bg-background text-on-surface antialiased">
        {children}
      </body>
    </html>
  );
}
