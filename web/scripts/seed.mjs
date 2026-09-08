#!/usr/bin/env node
// Jalankan: npm run seed
// (baca .env.local via `node --env-file=.env.local`, sudah diset di package.json)

const url = process.env.SEED_URL || "http://localhost:3000/api/seed";
const secret = process.env.SEED_SECRET;

if (!secret) {
  console.error("SEED_SECRET belum diisi di .env.local — isi dulu sebelum menjalankan seed.");
  process.exit(1);
}

const res = await fetch(url, {
  method: "POST",
  headers: { "X-Seed-Secret": secret },
});

const json = await res.json().catch(() => ({}));

if (!res.ok || !json.ok) {
  console.error(`Seed gagal (HTTP ${res.status}):`, json);
  process.exit(1);
}

console.log("Seed berhasil:", json);
console.log("Server dev (npm run dev) harus sedang jalan di", url, "sebelum menjalankan ini.");
