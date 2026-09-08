import { Suspense } from "react";
import LaporClient from "./LaporClient";

export default function LaporPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center p-6 text-sm text-muted">
          Memuat…
        </main>
      }
    >
      <LaporClient />
    </Suspense>
  );
}
