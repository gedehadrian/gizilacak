"use client";

import type { StatusKonsumsi } from "@/lib/status";

const STYLES: Record<
  StatusKonsumsi,
  { bg: string; text: string; ring: string }
> = {
  "dalam-batas": {
    bg: "bg-success-bg",
    text: "text-success",
    ring: "ring-success/30",
  },
  "mendekati-batas": {
    bg: "bg-warning-bg",
    text: "text-warning",
    ring: "ring-warning/30",
  },
  "lewat-batas": {
    bg: "bg-danger-bg",
    text: "text-danger",
    ring: "ring-danger/30",
  },
  "belum-terverifikasi": {
    bg: "bg-[#f5f6fa]",
    text: "text-muted",
    ring: "ring-border",
  },
};

export function StatusBadge({
  status,
  label,
  size = "md",
}: {
  status: StatusKonsumsi;
  label: string;
  size?: "md" | "lg";
}) {
  const s = STYLES[status];
  const sizeCls =
    size === "lg"
      ? "text-lg sm:text-xl px-5 py-3 rounded-2xl"
      : "text-sm px-3 py-1.5 rounded-full";

  return (
    <span
      className={`inline-flex items-center justify-center font-bold ring-4 ${s.bg} ${s.text} ${s.ring} ${sizeCls}`}
      role="status"
    >
      {label}
    </span>
  );
}
