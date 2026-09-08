import { NextRequest, NextResponse } from "next/server";
import QRCode from "qrcode";

export async function GET(req: NextRequest) {
  const url = req.nextUrl.searchParams.get("url");
  if (!url) {
    return NextResponse.json({ error: "Parameter url wajib" }, { status: 400 });
  }

  try {
    const dataUrl = await QRCode.toDataURL(url, {
      width: 320,
      margin: 2,
      errorCorrectionLevel: "M",
    });
    return NextResponse.json({ dataUrl });
  } catch {
    return NextResponse.json({ error: "Gagal membuat QR" }, { status: 500 });
  }
}
