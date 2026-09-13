-- Insert policies for audit_logs and exports (authenticated members).
drop policy if exists aud_ins on public.audit_logs;
create policy aud_ins on public.audit_logs for insert to authenticated
  with check (actor_id = auth.uid());
drop policy if exists expx_ins on public.exports;
create policy expx_ins on public.exports for insert to authenticated
  with check (requested_by = auth.uid());
drop policy if exists notif_ins on public.notifications;
create policy notif_ins on public.notifications for insert to authenticated
  with check (recipient_id = auth.uid() or public.is_tenant_member(tenant_id, array['owner','manager']));
