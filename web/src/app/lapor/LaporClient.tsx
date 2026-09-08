"use client";

import { FormEvent, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { PinGate } from "@/components/PinGate";
import { formatWaktu } from "@/lib/format";
import { hashPin } from "@/lib/pin";
import { supabase } from "@/lib/supabase";
import type { Batch, Laporan, Sekolah } from "@/lib/types";
import Link from "next/link";

const SESSION_KEY = "gizilacak_sekolah_session";

interface Session {
  sekolahId: string;
  nama: string;
  kode: string;
}

export default function LaporClient() {
  const searchParams = useSearchParams();
  const tokenFromUrl = searchParams.get("token") ?? "";

  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [token, setToken] = useState(tokenFromUrl);
  const [batch, setBatch] = useState<Batch | null>(null);
  const [riwayat, setRiwayat] = useState<Laporan[]>([]);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

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
    if (tokenFromUrl) setToken(tokenFromUrl);
  }, [tokenFromUrl]);

  useEffect(() => {
    if (!session) return;
    void loadRiwayat(session.sekolahId);
  }, [session]);

  useEffect(() => {
    if (!token.trim()) {
      setBatch(null);
      return;
    }
    const t = setTimeout(() => {
      void lookupBatch(token.trim());
    }, 300);
    return () => clearTimeout(t);
  }, [token]);

  async function loadRiwayat(sekolahId: string) {
    const { data } = await supabase
      .from("laporan")
      .select("*")
      .eq("sekolah_id", sekolahId)
      .order("waktu_lapor", { ascending: false })
      .limit(10);
    setRiwayat((data as Laporan[]) ?? []);
  }

  async function lookupBatch(kode: string) {
    const { data } = await supabase
      .from("batch")
      .select("*")
      .eq("kode_qr", kode)
      .maybeSingle();
    setBatch((data as Batch) ?? null);
  }

  async function handleLogin(pin: string): Promise<string | null> {
    const pinHash = await hashPin(pin);
    const { data, error: qErr } = await supabase
      .from("sekolah")
      .select("id, nama, kode_sekolah, pin_hash")
      .eq("pin_hash", pinHash)
      .maybeSingle();

    if (qErr) return `Gagal login: ${qErr.message}`;
    if (!data) return "PIN sekolah tidak cocok.";

    const sekolah = data as Sekolah;
    const next: Session = {
      sekolahId: sekolah.id,
      nama: sekolah.nama,
      kode: sekolah.kode_sekolah,
    };
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(next));
    setSession(next);
    return null;
  }

  function logout() {
    sessionStorage.removeItem(SESSION_KEY);
    setSession(null);
  }

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!session || !batch) {
      setError("Cari batch dulu lewat token QR.");
      return;
    }
    setSaving(true);
    setError(null);
    setMessage(null);

    const fd = new FormData(e.currentTarget);
    const jenis = String(fd.get("jenis") || "");
    const payload = {
      batch_id: batch.id,
      sekolah_id: session.sekolahId,
      jenis,
      catatan: String(fd.get("catatan") || "").trim() || null,
      nama_pelapor: String(fd.get("nama_pelapor") || "").trim() || null,
    };

    const { error: insertErr } = await supabase.from("laporan").insert(payload);
    if (insertErr) {
      setError(insertErr.message);
      setSaving(false);
      return;
    }

    if (jenis === "diterima") {
      await supabase.from("batch").update({ status: "diterima" }).eq("id", batch.id);
    } else if (jenis === "ditolak") {
      await supabase.from("batch").update({ status: "ditolak" }).eq("id", batch.id);
    }

    setMessage("Laporan berhasil dikirim.");
    e.currentTarget.reset();
    await loadRiwayat(session.sekolahId);
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
          title="Laporan Guru / UKS"
          subtitle="Masuk dengan PIN sekolah untuk mencatat penerimaan MBG."
          hint="Demo: PIN sekolah = 5678 (SDN Contoh Tangerang)"
          onSubmit={handleLogin}
        />
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md bg-background px-4 py-6">
      <header className="mb-5 flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-extrabold">
            <span className="text-primary">Gizi</span>Lacak
          </p>
          <h1 className="text-lg font-extrabold">Laporan Guru / UKS</h1>
          <p className="text-xs text-muted">{session.nama}</p>
        </div>
        <button
          type="button"
          onClick={logout}
          className="rounded-xl border border-border px-3 py-2 text-xs font-semibold"
        >
          Keluar
        </button>
      </header>

      <form
        onSubmit={handleSubmit}
        className="space-y-4 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]"
      >
        <label className="block text-sm font-semibold">
          Token / kode QR batch
          <input
            value={token}
            onChange={(e) => setToken(e.target.value)}
            placeholder="Tempel token dari QR"
            className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-4 py-3 text-sm outline-none focus:border-primary"
            required
          />
        </label>

        {batch ? (
          <div className="rounded-xl bg-primary-soft/60 px-3 py-2 text-sm">
            <p className="font-bold">{batch.nama_komponen_menu}</p>
            <p className="text-xs text-muted">
              Matang: {formatWaktu(batch.waktu_selesai_masak)} ·{" "}
              <Link className="text-primary underline" href={`/scan/${batch.kode_qr}`}>
                lihat status
              </Link>
            </p>
          </div>
        ) : token.trim() ? (
          <p className="text-sm text-danger">Batch tidak ditemukan untuk token ini.</p>
        ) : null}

        <fieldset className="space-y-2">
          <legend className="text-sm font-semibold">Jenis laporan</legend>
          {[
            ["diterima", "Diterima"],
            ["ditolak", "Ditolak"],
            ["dilaporkan_bermasalah", "Dilaporkan bermasalah"],
          ].map(([value, label]) => (
            <label
              key={value}
              className="flex items-center gap-2 rounded-xl border border-border px-3 py-3 text-sm"
            >
              <input type="radio" name="jenis" value={value} required />
              {label}
            </label>
          ))}
        </fieldset>

        <label className="block text-sm font-semibold">
          Nama pelapor
          <input
            name="nama_pelapor"
            required
            className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-4 py-3 text-sm outline-none focus:border-primary"
          />
        </label>

        <label className="block text-sm font-semibold">
          Catatan
          <textarea
            name="catatan"
            rows={3}
            className="mt-1 w-full rounded-xl border border-border bg-[#f5f6fa] px-4 py-3 text-sm outline-none focus:border-primary"
            placeholder="Opsional"
          />
        </label>

        <button
          type="submit"
          disabled={saving || !batch}
          className="w-full rounded-xl bg-primary px-4 py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {saving ? "Mengirim…" : "Kirim laporan"}
        </button>

        {error ? <p className="text-sm font-semibold text-danger">{error}</p> : null}
        {message ? (
          <p className="text-sm font-semibold text-success">{message}</p>
        ) : null}
      </form>

      <section className="mt-5 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
        <h2 className="text-sm font-extrabold">Riwayat singkat</h2>
        <ul className="mt-3 space-y-2">
          {riwayat.length === 0 ? (
            <li className="text-sm text-muted">Belum ada laporan.</li>
          ) : (
            riwayat.map((r) => (
              <li
                key={r.id}
                className="rounded-xl border border-border px-3 py-2 text-sm"
              >
                <p className="font-semibold capitalize">
                  {r.jenis.replaceAll("_", " ")}
                </p>
                <p className="text-xs text-muted">
                  {formatWaktu(r.waktu_lapor)}
                  {r.nama_pelapor ? ` · ${r.nama_pelapor}` : ""}
                </p>
              </li>
            ))
          )}
        </ul>
      </section>
    </main>
  );
}
