import { createHash } from "crypto";
import { createSupabaseAdmin } from "@/lib/supabase/admin";
import { hitungStatusKonsumsiKomponen, statusPalingMendesak } from "@/lib/status";

export type PublicScanDto = {
  kind: "delivery";
  token: string;
  valid: boolean;
  message?: string;
  fetched_at: string;
  server_now: string;
  delivery?: {
    code: string;
    status: string;
    dispatched_at: string | null;
    school_name: string | null;
    sppg_name: string | null;
    sppg_code: string | null;
  };
  components: Array<{
    name: string;
    cooked_at: string | null;
    consume_by: string | null;
    warning_minutes: number | null;
    portion_grams: number | null;
    kcal: number | null;
    protein_g: number | null;
    carbs_g: number | null;
    fat_g: number | null;
    ingredients: string[];
    allergens: string[];
    allergen_state: string;
    nutrition_source: string | null;
    status: ReturnType<typeof hitungStatusKonsumsiKomponen>;
  }>;
  overall: ReturnType<typeof hitungStatusKonsumsiKomponen>;
};

function emptyDto(token: string, message: string, valid = false): PublicScanDto {
  const now = new Date();
  const overall = hitungStatusKonsumsiKomponen(null, null, null, now);
  return {
    kind: "delivery",
    token,
    valid,
    message,
    fetched_at: now.toISOString(),
    server_now: now.toISOString(),
    components: [],
    overall,
  };
}

export async function loadPublicScan(token: string): Promise<PublicScanDto> {
  const now = new Date();
  if (!token || token.length < 8 || token.length > 128) {
    return emptyDto(token, "Token QR tidak valid.");
  }

  const admin = createSupabaseAdmin();
  const { data: label } = await admin
    .from("qr_labels")
    .select("id, token, revoked_at, revoke_reason, delivery_id, tenant_id")
    .eq("token", token)
    .maybeSingle();

  if (label) {
    if (label.revoked_at) {
      return emptyDto(token, `QR ini sudah dirotasi atau dibatalkan. ${label.revoke_reason ?? ""}`.trim());
    }
    const { data: delivery } = await admin
      .from("deliveries")
      .select("id, code, status, dispatched_at, school_id, tenant_id")
      .eq("id", label.delivery_id)
      .maybeSingle();
    if (!delivery) return emptyDto(token, "Data belum dapat diverifikasi.");

    const [{ data: school }, { data: tenant }, { data: items }] = await Promise.all([
      admin.from("schools").select("name").eq("id", delivery.school_id).maybeSingle(),
      admin.from("tenants").select("name, sppg_code").eq("id", delivery.tenant_id).maybeSingle(),
      admin.from("delivery_items").select("id, portions, batch_component_id").eq("delivery_id", delivery.id),
    ]);

    const componentIds = (items ?? []).map((i: { batch_component_id: string }) => i.batch_component_id);
    const { data: components } = componentIds.length
      ? await admin
          .from("batch_components")
          .select(
            "id, name, cooked_at, consume_by, warning_minutes_snapshot, duration_minutes_snapshot, portion_grams, kcal, protein_g, carbs_g, fat_g, ingredients, allergens, allergen_state, nutrition_source"
          )
          .in("id", componentIds)
      : { data: [] as Record<string, unknown>[] };

    const mapped = (components ?? []).map((c: Record<string, unknown>) => {
      const status = hitungStatusKonsumsiKomponen(
        (c.cooked_at as string) ?? null,
        (c.consume_by as string) ?? null,
        (c.warning_minutes_snapshot as number) ?? null,
        now
      );
      return {
        name: String(c.name),
        cooked_at: (c.cooked_at as string) ?? null,
        consume_by: (c.consume_by as string) ?? null,
        warning_minutes: (c.warning_minutes_snapshot as number) ?? null,
        portion_grams: c.portion_grams == null ? null : Number(c.portion_grams),
        kcal: c.kcal == null ? null : Number(c.kcal),
        protein_g: c.protein_g == null ? null : Number(c.protein_g),
        carbs_g: c.carbs_g == null ? null : Number(c.carbs_g),
        fat_g: c.fat_g == null ? null : Number(c.fat_g),
        ingredients: (c.ingredients as string[]) ?? [],
        allergens: (c.allergens as string[]) ?? [],
        allergen_state: String(c.allergen_state ?? "unknown"),
        nutrition_source: (c.nutrition_source as string) ?? null,
        status,
      };
    });

    return {
      kind: "delivery",
      token,
      valid: true,
      fetched_at: now.toISOString(),
      server_now: now.toISOString(),
      delivery: {
        code: delivery.code,
        status: delivery.status,
        dispatched_at: delivery.dispatched_at,
        school_name: school?.name ?? null,
        sppg_name: tenant?.name ?? null,
        sppg_code: tenant?.sppg_code ?? null,
      },
      components: mapped,
      overall: statusPalingMendesak(mapped.map((m) => m.status)),
    };
  }

  return emptyDto(token, "QR tidak dikenali atau sudah tidak berlaku.");
}

export async function recordScanEvent(token: string, eventKey: string, actorKind: "public" | "school" | "staff") {
  const admin = createSupabaseAdmin();
  const { data: label } = await admin.from("qr_labels").select("id, tenant_id").eq("token", token).maybeSingle();
  if (!label) return { recorded: false };
  const key = createHash("sha256").update(eventKey).digest("hex").slice(0, 64);
  await admin.from("scan_logs").insert({
    tenant_id: label.tenant_id,
    qr_label_id: label.id,
    actor_kind: actorKind,
    event_key: key,
  });
  return { recorded: true };
}
