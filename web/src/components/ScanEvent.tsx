"use client";

import { useEffect } from "react";

export function ScanEvent({ token }: { token: string }) {
  useEffect(() => {
    const key = `${token}:${sessionStorage.getItem("gzl_scan") ? "repeat" : crypto.randomUUID()}`;
    sessionStorage.setItem("gzl_scan", "1");
    fetch(`/api/public/scan/${encodeURIComponent(token)}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ event_key: key }),
    }).catch(() => undefined);
  }, [token]);
  return null;
}
