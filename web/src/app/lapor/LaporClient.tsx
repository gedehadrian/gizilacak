"use client";

import { FormEvent, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { PinGate } from "@/components/PinGate";
import { formatWaktu } from "@/lib/format";
import type { Laporan } from "@/lib/types";
import Link from "next/link";

interface Session {
  sekolahId: string;
  nama: string;
  kode: string;
}

interface BatchPreview {
  id: string;
  nama_komponen_menu: string;
  waktu_selesai_masak: string;
  kode_qr: string;
}

export default function LaporClient() {
  const searchParams = useSearchParams();
  const tokenFromUrl = searchParams.get("token") ?? "";

  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [token, setToken] = useState(tokenFromUrl);
  const [batch, setBatch] = useState<BatchPreview | null>(null);
  const [batchNotFound, setBatchNotFound] = useState(false);
  const [riwayat, setRiwayat] = useState<Laporan[]>([]);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/auth/me?role=sekolah");
        const json = await res.json();
        if (json?.loggedIn && json.session) {
          setSession({
            sekolahId: json.session.id,
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
    if (tokenFromUrl) setToken(tokenFromUrl);
  }, [tokenFromUrl]);

  useEffect(() => {
    if (!session) return;
    void loadRiwayat();
  }, [session]);

  useEffect(() => {
    if (!session || !token.trim()) {
      setBatch(null);
      setBatchNotFound(false);
      return;
    }
    const t = setTimeout(() => {
      void lookupBatch(token.trim());
    }, 300);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, session]);

  async function loadRiwayat() {
    const res = await fetch("/api/laporan");
    const json = await res.json();
    setRiwayat(res.ok && json.ok ? (json.laporan as Laporan[]) : []);
  }

  async function lookupBatch(kode: string) {
    const res = await fetch(`/api/batch/lookup?token=${encodeURIComponent(kode)}`);
    const json = await res.json();
    if (res.ok && json.ok && json.batch) {
      setBatch(json.batch as BatchPreview);
      setBatchNotFound(false);
    } else {
      setBatch(null);
      setBatchNotFound(true);
    }
  }

  async function handleLogin(pin: string): Promise<string | null> {
    const res = await fetch("/api/auth/sekolah", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pin }),
    });
    const json = await res.json();
    if (!res.ok || !json.ok) return json.error || "PIN sekolah tidak cocok.";

    setSession({
      sekolahId: json.sekolah.id,
      nama: json.sekolah.nama,
      kode: json.sekolah.kode_sekolah,
    });
    return null;
  }

  async function logout() {
    await fetch("/api/auth/logout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role: "sekolah" }),
    });
    setSession(null);
    setRiwayat([]);
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
    const payload = {
      token: batch.kode_qr,
      jenis: String(fd.get("jenis") || ""),
      catatan: String(fd.get("catatan") || "").trim() || null,
      nama_pelapor: String(fd.get("nama_pelapor") || "").trim() || null,
    };

    const res = await fetch("/api/laporan", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const json = await res.json();

    if (!res.ok || !json.ok) {
      setError(json.error || "Gagal mengirim laporan.");
      setSaving(false);
      return;
    }

    setMessage("Laporan berhasil dikirim.");
    e.currentTarget.reset();
    await loadRiwayat();
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
          hint="Demo: PIN sekolah = 5678 (SDN Contoh Tangerang) — setelah `npm run seed`."
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

      <form onSubmit={handleSubmit} className="space-y-4 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
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
        ) : batchNotFound && token.trim() ? (
          <p className="text-sm text-danger">Batch tidak ditemukan untuk token ini.</p>
        ) : null}

        <fieldset className="space-y-2">
          <legend className="text-sm font-semibold">Jenis laporan</legend>
          {[
            ["diterima", "Diterima"],
            ["ditolak", "Ditolak"],
            ["dilaporkan_bermasalah", "Dilaporkan bermasalah"],
          ].map(([value, label]) => (
            <label key={value} className="flex items-center gap-2 rounded-xl border border-border px-3 py-3 text-sm">
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
        {message ? <p className="text-sm font-semibold text-success">{message}</p> : null}
      </form>

      <section className="mt-5 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
        <h2 className="text-sm font-extrabold">Riwayat singkat</h2>
        <ul className="mt-3 space-y-2">
          {riwayat.length === 0 ? (
            <li className="text-sm text-muted">Belum ada laporan.</li>
          ) : (
            riwayat.map((r) => (
              <li key={r.id} className="rounded-xl border border-border px-3 py-2 text-sm">
                <p className="font-semibold capitalize">{r.jenis.replaceAll("_", " ")}</p>
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
