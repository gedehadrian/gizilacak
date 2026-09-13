export const metadata = {
  title: "Pembayaran diterima — GiziLacak",
  description: "Halaman kembali setelah pembayaran Midtrans.",
};

export const dynamic = "force-dynamic";

/**
 * Midtrans harus mengembalikan peramban ke suatu alamat setelah pembayaran.
 * Halaman ini sengaja tipis dan tanpa login — satu-satunya pengecualian selain
 * /scan, karena tautan dalam (deep link) ke aplikasi tidak berfungsi kalau
 * pembayaran dibuka dari peramban desktop.
 *
 * Halaman ini TIDAK menyatakan langganan sudah aktif. Yang menentukan itu
 * webhook dari Midtrans ke server, bukan alamat yang dikembalikan ke peramban —
 * parameter di URL bisa diketik siapa saja.
 */
export default async function PaymentFinishedPage({
  searchParams,
}: {
  searchParams: Promise<{ order_id?: string; transaction_status?: string }>;
}) {
  const { order_id: orderId, transaction_status: status } = await searchParams;

  const settled = status === "settlement" || status === "capture";
  const pending = status === "pending";

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 p-6 text-center">
      <p className="text-sm font-extrabold">
        <span className="text-primary">Gizi</span>Lacak
      </p>

      <h1 className="text-xl font-extrabold">
        {settled
          ? "Pembayaran diterima"
          : pending
            ? "Pembayaran sedang diproses"
            : "Pembayaran belum selesai"}
      </h1>

      <p className="text-sm text-muted">
        {settled
          ? "Terima kasih. Status langganan diperbarui setelah Midtrans mengonfirmasi ke server kami — biasanya dalam hitungan menit."
          : pending
            ? "Selesaikan pembayaran sesuai petunjuk dari Midtrans. Status akan diperbarui otomatis setelah dikonfirmasi."
            : "Pembayaran tidak terselesaikan. Anda bisa mencobanya lagi dari aplikasi GiziLacak."}
      </p>

      {orderId ? (
        <p className="text-xs text-muted">
          Nomor pesanan: <span className="font-semibold">{orderId}</span>
        </p>
      ) : null}

      <p className="mt-2 text-xs text-muted">
        Kembali ke aplikasi GiziLacak untuk melihat status langganan.
      </p>
    </main>
  );
}
