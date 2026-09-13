export const metadata = {
  title: "GiziLacak",
  description:
    "Situs ini hanya melayani pemindaian QR. Staf SPPG dan sekolah memakai aplikasi GiziLacak.",
};

/**
 * Halaman depan sengaja tipis. Web tidak lagi punya login: staf SPPG dan guru
 * bekerja lewat aplikasi, dan situs ini hanya melayani /scan/[token] yang
 * dibuka siswa dari kamera HP.
 */
export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 p-6 text-center">
      <p className="text-2xl font-extrabold tracking-tight">
        <span className="text-primary">Gizi</span>
        <span className="text-foreground">Lacak</span>
      </p>
      <p className="text-sm text-muted">
        Situs ini dipakai untuk memindai QR pada dus makanan. Arahkan kamera HP ke QR,
        lalu buka tautan yang muncul.
      </p>
      <p className="text-xs text-muted">
        Staf SPPG dan guru masuk lewat aplikasi GiziLacak, bukan lewat situs ini.
      </p>
    </main>
  );
}
