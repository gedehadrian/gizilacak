-- Resolve pgcrypto in Supabase's trusted extensions schema without replacing the RPC body.
alter function public.dispatch_delivery(uuid) set search_path = public, extensions;

-- Explicit role grants survive REVOKE FROM PUBLIC; payment activation is server-only.
revoke execute on function public.activate_paid_invoice(uuid, uuid) from public, anon, authenticated;
grant execute on function public.activate_paid_invoice(uuid, uuid) to service_role;
