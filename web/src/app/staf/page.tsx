"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { DashboardShell } from "@/components/DashboardShell";
import { PinGate } from "@/components/PinGate";
import { formatWaktu, splitCsv } from "@/lib/format";
import type { Batch } from "@/lib/types";

interface Session {
  dapurId: string;
  nama: string;
  kode: string;
}

export default function StafPage() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [batches, setBatches] = useState<Batch[]>([]);
  const [qrDataUrl, setQrDataUrl] = useState<string | null>(null);
  const [lastToken, setLastToken] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const nowLocal = useMemo(() => {
    const d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  }, []);

  // Cek status login lewat cookie httpOnly di server (bukan sessionStorage) —
  // tidak bisa dipalsukan dari devtools karena cookie-nya tidak terbaca JS.
  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/auth/me?role=dapur");
        const json = await res.json();
        if (json?.loggedIn && json.session) {
          setSession({
            dapurId: json.session.id,
            nama: json.session.nama,
            kode: json.session.kode,
          });
        }
      } catch {
        /* ignore */
      } finally {
        setReady(true);
      }
    })();
  }, []);

  useEffect(() => {
    if (!session) return;
    void loadBatches();
  }, [session]);

  async function loadBatches() {
    const res = await fetch("/api/batch");
    if (!res.ok) return;
    const json = await res.json();
    setBatches((json.batches as Batch[]) ?? []);
  }

  async function handleLogin(pin: string): Promise<string | null> {
    const res = await fetch("/api/auth/dapur", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pin }),
    });
    const json = await res.json();
    if (!res.ok || !json.ok) return json.error || "PIN dapur tidak cocok.";

    setSession({
      dapurId: json.dapur.id,
      nama: json.dapur.nama,
      kode: json.dapur.kode_dapur,
    });
    return null;
  }

  async function logout() {
    await fetch("/api/auth/logout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role: "dapur" }),
    });
    setSession(null);
    setBatches([]);
    setQrDataUrl(null);
    setLastToken(null);
  }

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!session) return;
    setSaving(true);
    setError(null);
    setMessage(null);
    setQrDataUrl(null);

    const fd = new FormData(e.currentTarget);
    const payload = {
      nama_komponen_menu: String(fd.get("nama_komponen_menu") || ""),
      waktu_selesai_masak: String(fd.get("waktu_selesai_masak") || ""),
      waktu_kirim: String(fd.get("waktu_kirim") || "") || null,
      kalori: fd.get("kalori"),
      protein: fd.get("protein"),
      karbohidrat: fd.get("karbohidrat"),
      lemak: fd.get("lemak"),
      daftar_alergen: splitCsv(String(fd.get("daftar_alergen") || "")),
      daftar_bahan: splitCsv(String(fd.get("daftar_bahan") || "")),
      ambang_batas_konsumsi_jam: Number(fd.get("ambang_batas_konsumsi_jam") || 4),
    };

    const res = await fetch("/api/batch", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const json = await res.json();

    if (!res.ok || !json.ok) {
      setError(json.error || "Gagal menyimpan batch.");
      setSaving(false);
      return;
    }

    const token: string = json.batch.kode_qr;
    const scanUrl = `${window.location.origin}/scan/${token}`;
    const qrRes = await fetch(`/api/qr?url=${encodeURIComponent(scanUrl)}`);
    const qrJson = (await qrRes.json()) as { dataUrl?: string; error?: string };
    if (qrJson.dataUrl) {
      setQrDataUrl(qrJson.dataUrl);
      setLastToken(token);
    }

    setMessage(`Batch tersimpan. Token QR: ${token}`);
    e.currentTarget.reset();
    await loadBatches();
    setSaving(false);
  }

  if (!ready) {
    return (
      <main className="flex min-h-screen items-center justify-center p-6 text-sm text-muted">
        Memuat…
      </main>
    );
  }

  if (!session) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-background p-4">
        <PinGate
          title="Masuk Staf SPPG"
          subtitle="Masukkan PIN dapur untuk mencatat batch masak & menerbitkan QR."
          hint="Demo: PIN dapur = 1234 (SPPG Cisauk Demo) — setelah `npm run seed`."
          onSubmit={handleLogin}
        />
      </main>
    );
  }

  return (
    <DashboardShell title={`Input Batch — ${session.nama}`} onLogout={logout}>
      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <section className="rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
          <h2 className="text-base font-extrabold">Catat batch baru</h2>
          <p className="mt-1 text-sm text-muted">
            Isi waktu selesai masak, data gizi, lalu terbitkan QR untuk sekolah.
          </p>

          <form onSubmit={handleSubmit} className="mt-5 grid gap-4 sm:grid-cols-2">
            <Field label="Nama komponen menu" className="sm:col-span-2">
              <input
                name="nama_komponen_menu"
                required
                placeholder="Contoh: Nasi + Ayam kecap"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Waktu selesai masak">
              <input
                name="waktu_selesai_masak"
                type="datetime-local"
                required
                defaultValue={nowLocal}
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Waktu kirim (opsional)">
              <input
                name="waktu_kirim"
                type="datetime-local"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Kalori (kkal)">
              <input
                name="kalori"
                type="number"
                step="0.1"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Protein (g)">
              <input
                name="protein"
                type="number"
                step="0.1"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Karbohidrat (g)">
              <input
                name="karbohidrat"
                type="number"
                step="0.1"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Lemak (g)">
              <input
                name="lemak"
                type="number"
                step="0.1"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Ambang batas konsumsi (jam)">
              <input
                name="ambang_batas_konsumsi_jam"
                type="number"
                step="0.5"
                min={1}
                defaultValue={4}
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Daftar alergen (pisah koma)" className="sm:col-span-2">
              <input
                name="daftar_alergen"
                placeholder="kacang, susu, telur"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <Field label="Daftar bahan (pisah koma)" className="sm:col-span-2">
              <input
                name="daftar_bahan"
                placeholder="beras, ayam, kecap, wortel"
                className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-3.5 py-2.5 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </Field>
            <div className="sm:col-span-2">
              <button
                type="submit"
                disabled={saving}
                className="w-full rounded-xl bg-primary px-4 py-3 text-sm font-bold text-white disabled:opacity-60 sm:w-auto"
              >
                {saving ? "Menyimpan…" : "Simpan & terbitkan QR"}
              </button>
            </div>
            {error ? (
              <p className="sm:col-span-2 text-sm font-semibold text-danger">{error}</p>
            ) : null}
            {message ? (
              <p className="sm:col-span-2 text-sm font-semibold text-success">{message}</p>
            ) : null}
          </form>
        </section>

        <section className="rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
          <h2 className="text-base font-extrabold">QR terbaru</h2>
          {qrDataUrl ? (
            <div className="mt-4 flex flex-col items-center gap-3">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={qrDataUrl} alt={`QR batch ${lastToken}`} className="h-56 w-56" />
              <p className="text-center text-xs text-muted">
                Token: <span className="font-mono">{lastToken}</span>
              </p>
            </div>
          ) : (
            <p className="mt-3 text-sm text-muted">
              Belum ada QR yang diterbitkan sesi ini. Simpan batch baru untuk melihatnya.
            </p>
          )}

          <h3 className="mt-6 text-sm font-extrabold">Batch terbaru dapur ini</h3>
          <ul className="mt-3 space-y-2">
            {batches.length === 0 ? (
              <li className="text-sm text-muted">Belum ada batch tercatat.</li>
            ) : (
              batches.map((b) => (
                <li key={b.id} className="rounded-xl border border-border px-3 py-2 text-sm">
                  <p className="font-semibold">{b.nama_komponen_menu}</p>
                  <p className="text-xs text-muted">
                    {formatWaktu(b.waktu_selesai_masak)} · {b.kode_qr}
                  </p>
                </li>
              ))
            )}
          </ul>
        </section>
      </div>
    </DashboardShell>
  );
}

function Field({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`block text-sm font-semibold ${className ?? ""}`}>
      {label}
      {children}
    </label>
  );
}
