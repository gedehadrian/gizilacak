import { z } from "zod";
import { jsonError } from "@/lib/http";

export async function readJson<T>(req: Request, schema: z.ZodType<T>) {
  const raw = await req.json().catch(() => null);
  if (!raw || typeof raw !== "object") {
    return { error: jsonError(422, "invalid", "Body JSON tidak valid.") };
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      fieldErrors[issue.path.join(".") || "body"] = issue.message;
    }
    return { error: jsonError(422, "invalid", "Input tidak valid.", fieldErrors) };
  }
  return { data: parsed.data };
}
