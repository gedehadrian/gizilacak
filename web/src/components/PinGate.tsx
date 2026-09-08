"use client";

import { FormEvent, useState } from "react";

export function PinGate({
  title,
  subtitle,
  onSubmit,
  hint,
}: {
  title: string;
  subtitle?: string;
  hint?: string;
  onSubmit: (pin: string) => Promise<string | null>;
}) {
  const [pin, setPin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    try {
      const err = await onSubmit(pin);
      if (err) setError(err);
    } catch {
      setError("Gagal memverifikasi PIN. Coba lagi.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto w-full max-w-md rounded-[14px] bg-card p-6 shadow-[var(--shadow-card)]">
      <h1 className="text-xl font-extrabold text-foreground">{title}</h1>
      {subtitle ? (
        <p className="mt-1 text-sm text-muted">{subtitle}</p>
      ) : null}
      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <label className="block text-sm font-semibold">
          PIN
          <input
            type="password"
            inputMode="numeric"
            autoComplete="one-time-code"
            value={pin}
            onChange={(e) => setPin(e.target.value)}
            className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-4 py-3 text-base outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            placeholder="Masukkan PIN"
            required
          />
        </label>
        {hint ? <p className="text-xs text-muted">{hint}</p> : null}
        {error ? (
          <p className="text-sm font-semibold text-danger">{error}</p>
        ) : null}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-xl bg-primary px-4 py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {loading ? "Memeriksa…" : "Masuk"}
        </button>
      </form>
    </div>
  );
}
