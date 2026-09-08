"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  { href: "/staf", label: "Input Batch" },
  { href: "/admin", label: "Dashboard" },
  { href: "/lapor", label: "Laporan Guru" },
  { href: "/", label: "Beranda" },
];

export function DashboardShell({
  title,
  children,
  onLogout,
}: {
  title: string;
  children: React.ReactNode;
  onLogout?: () => void;
}) {
  const pathname = usePathname();

  return (
    <div className="min-h-screen bg-background lg:flex">
      <aside className="hidden w-60 shrink-0 border-r border-border bg-card lg:flex lg:flex-col">
        <div className="px-6 py-5">
          <Link href="/" className="text-xl font-extrabold tracking-tight">
            <span className="text-primary">Gizi</span>
            <span className="text-foreground">Lacak</span>
          </Link>
          <p className="mt-1 text-xs text-muted">Verifikasi MBG · Kab. Tangerang</p>
        </div>
        <nav className="flex flex-1 flex-col gap-1 px-3 py-2">
          {NAV.map((item) => {
            const active = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`rounded-xl px-4 py-3 text-sm font-semibold transition ${
                  active
                    ? "bg-primary text-white"
                    : "text-foreground hover:bg-primary-soft"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        {onLogout ? (
          <button
            type="button"
            onClick={onLogout}
            className="m-3 rounded-xl border border-border px-4 py-3 text-left text-sm font-semibold text-muted hover:bg-[#f5f6fa]"
          >
            Keluar
          </button>
        ) : null}
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-border bg-card px-4 py-4 sm:px-6">
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-muted lg:hidden">
              <Link href="/">
                <span className="text-primary">Gizi</span>Lacak
              </Link>
            </p>
            <h1 className="text-lg font-extrabold sm:text-xl">{title}</h1>
          </div>
          {onLogout ? (
            <button
              type="button"
              onClick={onLogout}
              className="rounded-xl border border-border px-3 py-2 text-xs font-semibold lg:hidden"
            >
              Keluar
            </button>
          ) : null}
        </header>
        <main className="flex-1 p-4 sm:p-6">{children}</main>
      </div>
    </div>
  );
}
