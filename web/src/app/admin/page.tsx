"use client";

import { useEffect, useMemo, useState } from "react";
import { DashboardShell } from "@/components/DashboardShell";
import { PinGate } from "@/components/PinGate";
import { StatusBadge } from "@/components/StatusBadge";
import { formatWaktu } from "@/lib/format";
import { hitungStatusKonsumsi } from "@/lib/status";
import type { Laporan, ScanLog } from "@/lib/types";
import Link from "next/link";

interface BatchRow {
  id: string;
  dapur_id: string;
  nama_komponen_menu: string;
  waktu_selesai_masak: string;
  waktu_kirim: string | null;
  kalori: number | null;
  protein: number | null;
  karbohidrat: number | null;
  lemak: number | null;
  daftar_alergen: string[] | null;
  daftar_bahan: string[] | null;
  ambang_batas_konsumsi_jam: number;
  kode_qr: string;
  status: string;
  created_at: string;
  dapur?: { nama: string; kode_dapur: string } | null;
  scan_count?: number;
  laporan_count?: number;
}

export default function AdminPage() {
  const [authed, setAuthed] = useState(false);
  const [ready, setReady] = useState(false);
  const [rows, setRows] = useState<BatchRow[]>([]);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<BatchRow | null>(null);
  const [scans, setScans] = useState<ScanLog[]>([]);
  const [laporans, setLaporans] = useState<Laporan[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/auth/me?role=admin");
        const json = await res.json();
        if (json?.loggedIn) setAuthed(true);
      } catch {
        /* ignore */
      } finally {
        setReady(true);
      }
    })();
  }, []);

  useEffect(() => {
    if (authed) void loadBatches();
  }, [authed]);

  async function handleLogin(pin: string): Promise<string | null> {
    const res = await fetch("/api/auth/admin", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ pin }),
    });
    const json = await res.json();
    if (!res.ok || !json.ok) return json.error || "PIN admin salah.";
    setAuthed(true);
    return null;
  }

  async function logout() {
    await fetch("/api/auth/logout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ role: "admin" }),
    });
    setAuthed(false);
    setSelected(null);
    setRows([]);
  }

  async function loadBatches() {
    setLoading(true);
    const res = await fetch("/api/admin/batches");
    const json = await res.json();
    setRows(res.ok && json.ok ? (json.batches as BatchRow[]) : []);
    setLoading(false);
  }

  async function openDetail(b: BatchRow) {
    setSelected(b);
    const res = await fetch(`/api/admin/batches/${b.id}`);
    const json = await res.json();
    if (res.ok && json.ok) {
      setScans((json.scans as ScanLog[]) ?? []);
      setLaporans((json.laporans as Laporan[]) ?? []);
    } else {
      setScans([]);
      setLaporans([]);
    }
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return rows;
    return rows.filter((r) => {
      const dapurNama = r.dapur?.nama?.toLowerCase() ?? "";
      return (
        r.nama_komponen_menu.toLowerCase().includes(q) ||
        r.kode_qr.toLowerCase().includes(q) ||
        dapurNama.includes(q) ||
        r.status.toLowerCase().includes(q)
      );
    });
  }, [rows, query]);

  const summary = useMemo(() => {
    let dalam = 0;
    let mendekati = 0;
    let lewat = 0;
    for (const r of rows) {
      const s = hitungStatusKonsumsi(
        new Date(r.waktu_selesai_masak),
        Number(r.ambang_batas_konsumsi_jam) || 4
      ).status;
      if (s === "dalam-batas") dalam += 1;
      else if (s === "mendekati-batas") mendekati += 1;
      else lewat += 1;
    }
    return { total: rows.length, dalam, mendekati, lewat };
  }, [rows]);

  if (!ready) {
    return (
      <main className="flex min-h-screen items-center justify-center p-6 text-sm text-muted">
        Memuat…
      </main>
    );
  }

  if (!authed) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-background p-4">
        <PinGate
          title="Dashboard Admin"
          subtitle="Penelusuran batch & riwayat untuk investigasi insiden (demo)."
          hint="PIN admin diset lewat env var ADMIN_PIN di server."
          onSubmit={handleLogin}
        />
      </main>
    );
  }

  return (
    <DashboardShell title="Dashboard Admin / BGN (demo)" onLogout={logout}>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <SummaryCard label="Total batch" value={summary.total} />
        <SummaryCard label="Dalam batas waktu" value={summary.dalam} tone="success" />
        <SummaryCard label="Mendekati batas" value={summary.mendekati} tone="warning" />
        <SummaryCard label="Melewati batas" value={summary.lewat} tone="danger" />
      </div>

      <section className="mt-6 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="text-base font-extrabold">Semua batch</h2>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Cari menu, token QR, dapur…"
            className="w-full rounded-xl border border-border bg-[#f5f6fa] px-4 py-2.5 text-sm outline-none focus:border-primary sm:max-w-sm"
          />
        </div>

        <div className="mt-4 overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="border-b border-border text-xs uppercase text-muted">
              <tr>
                <th className="px-2 py-3 font-semibold">Menu</th>
                <th className="px-2 py-3 font-semibold">Dapur</th>
                <th className="px-2 py-3 font-semibold">Matang</th>
                <th className="px-2 py-3 font-semibold">Status konsumsi</th>
                <th className="px-2 py-3 font-semibold">Scan</th>
                <th className="px-2 py-3 font-semibold">Laporan</th>
                <th className="px-2 py-3 font-semibold" />
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} className="px-2 py-6 text-muted">
                    Memuat data…
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-2 py-6 text-muted">
                    Belum ada batch.
                  </td>
                </tr>
              ) : (
                filtered.map((r) => {
                  const hasil = hitungStatusKonsumsi(
                    new Date(r.waktu_selesai_masak),
                    Number(r.ambang_batas_konsumsi_jam) || 4
                  );
                  return (
                    <tr key={r.id} className="border-b border-border/70">
                      <td className="px-2 py-3 font-semibold">
                        {r.nama_komponen_menu}
                        <div className="text-xs font-normal text-muted">{r.kode_qr}</div>
                      </td>
                      <td className="px-2 py-3">{r.dapur?.nama ?? "—"}</td>
                      <td className="px-2 py-3 whitespace-nowrap">{formatWaktu(r.waktu_selesai_masak)}</td>
                      <td className="px-2 py-3">
                        <StatusBadge status={hasil.status} label={hasil.label} />
                      </td>
                      <td className="px-2 py-3">{r.scan_count ?? 0}</td>
                      <td className="px-2 py-3">{r.laporan_count ?? 0}</td>
                      <td className="px-2 py-3">
                        <button
                          type="button"
                          onClick={() => void openDetail(r)}
                          className="text-xs font-bold text-primary underline"
                        >
                          Detail
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </section>

      {selected ? (
        <section className="mt-6 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="text-base font-extrabold">Detail · {selected.nama_komponen_menu}</h2>
              <p className="text-sm text-muted">
                Token:{" "}
                <Link href={`/scan/${selected.kode_qr}`} className="font-semibold text-primary underline">
                  {selected.kode_qr}
                </Link>
              </p>
            </div>
            <button
              type="button"
              onClick={() => setSelected(null)}
              className="rounded-xl border border-border px-3 py-2 text-xs font-semibold"
            >
              Tutup
            </button>
          </div>

          <div className="mt-5 grid gap-5 lg:grid-cols-2">
            <div>
              <h3 className="text-sm font-extrabold">Timeline scan</h3>
              <ul className="mt-3 space-y-2">
                {scans.length === 0 ? (
                  <li className="text-sm text-muted">Belum ada scan.</li>
                ) : (
                  scans.map((s) => (
                    <li key={s.id} className="rounded-xl border border-border px-3 py-2 text-sm">
                      {formatWaktu(s.waktu_scan)} · {s.peran_pemindai ?? "publik"}
                    </li>
                  ))
                )}
              </ul>
            </div>
            <div>
              <h3 className="text-sm font-extrabold">Laporan terkait</h3>
              <ul className="mt-3 space-y-2">
                {laporans.length === 0 ? (
                  <li className="text-sm text-muted">Belum ada laporan.</li>
                ) : (
                  laporans.map((l) => (
                    <li key={l.id} className="rounded-xl border border-border px-3 py-2 text-sm">
                      <p className="font-semibold capitalize">{l.jenis.replaceAll("_", " ")}</p>
                      <p className="text-xs text-muted">
                        {formatWaktu(l.waktu_lapor)}
                        {l.nama_pelapor ? ` · ${l.nama_pelapor}` : ""}
                      </p>
                      {l.catatan ? <p className="mt-1 text-xs">{l.catatan}</p> : null}
                    </li>
                  ))
                )}
              </ul>
            </div>
          </div>
        </section>
      ) : null}
    </DashboardShell>
  );
}

function SummaryCard({
  label,
  value,
  tone = "default",
}: {
  label: string;
  value: number;
  tone?: "default" | "success" | "warning" | "danger";
}) {
  const toneCls =
    tone === "success"
      ? "text-success"
      : tone === "warning"
        ? "text-warning"
        : tone === "danger"
          ? "text-danger"
          : "text-primary";
  return (
    <div className="rounded-[14px] bg-card p-4 shadow-[var(--shadow-card)]">
      <p className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</p>
      <p className={`mt-2 text-3xl font-extrabold ${toneCls}`}>{value}</p>
    </div>
  );
}
