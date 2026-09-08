"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { DashboardShell } from "@/components/DashboardShell";
import { PinGate } from "@/components/PinGate";
import { formatWaktu, generateToken, splitCsv } from "@/lib/format";
import { hashPin } from "@/lib/pin";
import { supabase } from "@/lib/supabase";
import type { Batch, Dapur } from "@/lib/types";

const SESSION_KEY = "gizilacak_dapur_session";

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

  useEffect(() => {
    void fetch("/api/seed", { method: "POST" });
    try {
      const raw = sessionStorage.getItem(SESSION_KEY);
      if (raw) setSession(JSON.parse(raw) as Session);
    } catch {
      /* ignore */
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (!session) return;
    void loadBatches(session.dapurId);
  }, [session]);

  async function loadBatches(dapurId: string) {
    const { data } = await supabase
      .from("batch")
      .select("*")
      .eq("dapur_id", dapurId)
      .order("created_at", { ascending: false })
      .limit(20);
    setBatches((data as Batch[]) ?? []);
  }

  async function handleLogin(pin: string): Promise<string | null> {
    const pinHash = await hashPin(pin);
    const { data, error: qErr } = await supabase
      .from("dapur")
      .select("id, nama, kode_dapur, pin_hash")
      .eq("pin_hash", pinHash)
      .maybeSingle();

    if (qErr) return `Gagal login: ${qErr.message}`;
    if (!data) return "PIN dapur tidak cocok.";

    const dapur = data as Dapur;
    const next: Session = {
      dapurId: dapur.id,
      nama: dapur.nama,
      kode: dapur.kode_dapur,
    };
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(next));
    setSession(next);
    return null;
  }

  function logout() {
    sessionStorage.removeItem(SESSION_KEY);
    setSession(null);
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
    const token = generateToken();
    const waktuSelesai = String(fd.get("waktu_selesai_masak") || "");
    const waktuKirimRaw = String(fd.get("waktu_kirim") || "");
    const ambang = Number(fd.get("ambang_batas_konsumsi_jam") || 4);

    const payload = {
      dapur_id: session.dapurId,
      nama_komponen_menu: String(fd.get("nama_komponen_menu") || "").trim(),
      waktu_selesai_masak: new Date(waktuSelesai).toISOString(),
      waktu_kirim: waktuKirimRaw
        ? new Date(waktuKirimRaw).toISOString()
        : null,
      kalori: numOrNull(fd.get("kalori")),
      protein: numOrNull(fd.get("protein")),
      karbohidrat: numOrNull(fd.get("karbohidrat")),
      lemak: numOrNull(fd.get("lemak")),
      daftar_alergen: splitCsv(String(fd.get("daftar_alergen") || "")),
      daftar_bahan: splitCsv(String(fd.get("daftar_bahan") || "")),
      ambang_batas_konsumsi_jam: ambang,
      kode_qr: token,
      status: "dikirim",
    };

    const { error: insertErr } = await supabase.from("batch").insert(payload);
    if (insertErr) {
      setError(insertErr.message);
      setSaving(false);
      return;
    }

    const scanUrl = `${window.location.origin}/scan/${token}`;
    const qrRes = await fetch(`/api/qr?url=${encodeURIComponent(scanUrl)}`);
    const qrJson = (await qrRes.json()) as { dataUrl?: string; error?: string };
    if (qrJson.dataUrl) {
      setQrDataUrl(qrJson.dataUrl);
      setLastToken(token);
    }

    setMessage(`Batch tersimpan. Token QR: ${token}`);
    e.currentTarget.reset();
    await loadBatches(session.dapurId);
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
          hint="Demo: PIN dapur = 1234 (SPPG Cisauk Demo)"
          onSubmit={handleLogin}
        />
      </main>
    );
  }

  return (
    <DashboardShell
      title={`Input Batch — ${session.nama}`}
      onLogout={logout}
    >
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
                className="rounded-xl bg-primary px-5 py-3 text-sm font-bold text-white disabled:opacity-60"
              >
                {saving ? "Menyimpan…" : "Selesai Masak → Terbitkan QR"}
              </button>
            </div>
          </form>

          {error ? (
            <p className="mt-4 text-sm font-semibold text-danger">{error}</p>
          ) : null}
          {message ? (
            <p className="mt-4 text-sm font-semibold text-success">{message}</p>
          ) : null}
        </section>

        <section className="rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
          <h2 className="text-base font-extrabold">QR batch terbaru</h2>
          {qrDataUrl && lastToken ? (
            <div className="mt-4 flex flex-col items-center gap-3 text-center">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={qrDataUrl}
                alt={`QR untuk batch ${lastToken}`}
                className="h-56 w-56 rounded-xl border border-border bg-white p-2"
              />
              <p className="text-xs break-all text-muted">
                {typeof window !== "undefined"
                  ? `${window.location.origin}/scan/${lastToken}`
                  : `/scan/${lastToken}`}
              </p>
              <a
                href={`/scan/${lastToken}`}
                className="text-sm font-bold text-primary underline"
              >
                Buka halaman scan
              </a>
            </div>
          ) : (
            <p className="mt-4 text-sm text-muted">
              QR akan muncul di sini setelah batch disimpan.
            </p>
          )}

          <h3 className="mt-8 text-sm font-extrabold">Batch terakhir</h3>
          <ul className="mt-3 space-y-2">
            {batches.length === 0 ? (
              <li className="text-sm text-muted">Belum ada batch.</li>
            ) : (
              batches.map((b) => (
                <li
                  key={b.id}
                  className="rounded-xl border border-border px-3 py-2 text-sm"
                >
                  <p className="font-semibold">{b.nama_komponen_menu}</p>
                  <p className="text-xs text-muted">
                    Matang: {formatWaktu(b.waktu_selesai_masak)} ·{" "}
                    <a className="text-primary underline" href={`/scan/${b.kode_qr}`}>
                      scan
                    </a>
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
  className = "",
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`block text-sm font-semibold ${className}`}>
      {label}
      {children}
    </label>
  );
}

function numOrNull(v: FormDataEntryValue | null): number | null {
  if (v == null || String(v).trim() === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}
