-- Menerbitkan satu kiriman yang baru saja dimasak, lengkap dengan QR-nya.
--
-- Gunanya: menyediakan QR yang pasti masih dalam batas waktu konsumsi, kapan
-- pun dibutuhkan. Riwayat di seed_data_awal.sql sengaja berumur tiga hari,
-- jadi QR di sana memang dilaporkan melewati batas.
--
-- Jalankan tepat sebelum merekam. Boleh diulang; tiap kali menghasilkan
-- kiriman dan token baru. Keluarannya berisi tautan yang siap dibuka.

do $$
declare
  _email text := 'igedehadrian45@gmail.com';
  _alamat_web text := 'https://gizilacak.vercel.app';

  uid uuid;
  tid uuid;
  pid uuid;
  dur int;
  warn int;
  sid uuid;
  menu uuid;
  b uuid;
  d uuid;
  komp record;
  tok text;
  cap text;
  masak timestamptz := now() - interval '20 minutes';
begin
  select id into uid from auth.users where lower(email) = lower(_email);
  if uid is null then
    raise exception 'Akun % tidak ditemukan.', _email;
  end if;

  select tm.tenant_id into tid
  from public.tenant_memberships tm
  where tm.user_id = uid and tm.role = 'owner' and tm.status = 'active'
  order by tm.created_at
  limit 1;
  if tid is null then
    raise exception 'Akun % belum memiliki SPPG.', _email;
  end if;

  select id, duration_minutes, warning_minutes into pid, dur, warn
  from public.consumption_policies
  where tenant_id = tid
  order by version desc
  limit 1;

  select ts.school_id into sid
  from public.tenant_schools ts
  where ts.tenant_id = tid and ts.status = 'active'
  order by ts.created_at
  limit 1;
  if sid is null then
    raise exception 'Belum ada sekolah binaan aktif. Jalankan seed_data_awal.sql dulu.';
  end if;

  select id into menu
  from public.recipes
  where tenant_id = tid and archived_at is null
  order by created_at
  limit 1;
  if menu is null then
    raise exception 'Belum ada menu. Jalankan seed_data_awal.sql dulu.';
  end if;

  cap := to_char(now(), 'YYYYMMDDHH24MISS');

  insert into public.batches
    (tenant_id, code, recipe_id, production_date, status, notes,
     created_by, finalized_by, finalized_at)
  values (tid, 'BATCH-' || cap, menu, current_date, 'ready',
          'Produksi siap kirim.', uid, uid, masak)
  returning id into b;

  insert into public.batch_components
    (tenant_id, batch_id, name, portions_produced, cooked_at, policy_id,
     duration_minutes_snapshot, warning_minutes_snapshot, consume_by,
     kcal, protein_g, carbs_g, fat_g, portion_grams,
     ingredients, allergens, allergen_state, nutrition_source)
  select tid, b, rc.name, 150, masak, pid, dur, warn,
         masak + make_interval(mins => dur),
         rc.kcal, rc.protein_g, rc.carbs_g, rc.fat_g, rc.portion_grams,
         rc.ingredients, rc.allergens, rc.allergen_state, rc.nutrition_source
  from public.recipe_components rc
  where rc.tenant_id = tid and rc.recipe_id = menu
  order by rc.position;

  insert into public.deliveries
    (tenant_id, school_id, code, status, scheduled_at, dispatched_at,
     created_by, dispatched_by, idempotency_key)
  values (tid, sid, 'KRM-' || cap, 'dispatched', now(), now(), uid, uid, 'segar-' || cap)
  returning id into d;

  for komp in
    select id from public.batch_components where tenant_id = tid and batch_id = b
  loop
    insert into public.delivery_items (tenant_id, delivery_id, batch_component_id, portions)
    values (tid, d, komp.id, 150);
  end loop;

  tok := encode(gen_random_bytes(16), 'hex');
  insert into public.qr_labels (tenant_id, delivery_id, token)
  values (tid, d, tok);

  raise notice '--------------------------------------------------';
  raise notice 'Kiriman  : KRM-%', cap;
  raise notice 'Dimasak  : % (batas % menit)', masak, dur;
  raise notice 'Tautan QR: %/scan/%', _alamat_web, tok;
  raise notice '--------------------------------------------------';
end $$;
