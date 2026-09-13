-- Data awal untuk peragaan GiziLacak.
--
-- Menyiapkan yang memakan waktu bila diketik satu per satu: sekolah binaan,
-- tiga menu beserta komponen dan gizinya, serta riwayat kiriman beberapa hari
-- terakhir supaya layar tidak kosong.
--
-- Yang SENGAJA TIDAK dibuat di sini: batch dan kiriman hari ini. Dua hal itu
-- justru yang diperagakan langsung, jadi biarkan kosong.
--
-- Cara pakai: buka Supabase -> SQL Editor, tempel seluruh berkas ini, jalankan.
-- Aman dijalankan berulang; yang sudah ada tidak diduplikasi.

do $$
declare
  -- Ganti bila akun pemilik SPPG-nya berbeda.
  _email text := 'igedehadrian45@gmail.com';

  uid uuid;
  tid uuid;
  pid uuid;
  dur int;
  warn int;

  sekolah_a uuid;
  sekolah_b uuid;
  sekolah_c uuid;

  menu_a uuid;
  menu_b uuid;
  menu_c uuid;

  batch_lalu uuid;
  komp_nasi uuid;
  komp_lauk uuid;
  komp_sayur uuid;
  komp_buah uuid;

  kirim_1 uuid;
  kirim_2 uuid;
  item_id uuid;
  komp_id uuid;
  masak timestamptz;
begin
  select id into uid from auth.users where lower(email) = lower(_email);
  if uid is null then
    raise exception 'Akun % tidak ditemukan. Daftar dulu lewat aplikasi.', _email;
  end if;

  select tm.tenant_id into tid
  from public.tenant_memberships tm
  where tm.user_id = uid and tm.role = 'owner' and tm.status = 'active'
  order by tm.created_at
  limit 1;

  if tid is null then
    raise exception 'Akun % belum memiliki SPPG. Buat dulu lewat aplikasi, baru jalankan berkas ini.', _email;
  end if;

  select id, duration_minutes, warning_minutes into pid, dur, warn
  from public.consumption_policies
  where tenant_id = tid
  order by version desc
  limit 1;

  if pid is null then
    raise exception 'Kebijakan konsumsi belum ada untuk SPPG ini.';
  end if;

  ---------------------------------------------------------------------------
  -- 1. Sekolah binaan
  ---------------------------------------------------------------------------
  insert into public.schools (name, school_code, address)
  values ('SDN Mekarsari 01', 'SDN-MKS-01', 'Jl. Raya Mekarsari No. 12, Kabupaten Tangerang')
  on conflict (school_code) do nothing;
  select id into sekolah_a from public.schools where school_code = 'SDN-MKS-01';

  insert into public.schools (name, school_code, address)
  values ('SDN Sindangsari 02', 'SDN-SDS-02', 'Jl. Sindangsari No. 5, Kabupaten Tangerang')
  on conflict (school_code) do nothing;
  select id into sekolah_b from public.schools where school_code = 'SDN-SDS-02';

  insert into public.schools (name, school_code, address)
  values ('SDN Talagasari 03', 'SDN-TLS-03', 'Jl. Talagasari No. 21, Kabupaten Tangerang')
  on conflict (school_code) do nothing;
  select id into sekolah_c from public.schools where school_code = 'SDN-TLS-03';

  insert into public.tenant_schools (tenant_id, school_id, status, accepted_at)
  values (tid, sekolah_a, 'active', now()),
         (tid, sekolah_b, 'active', now()),
         (tid, sekolah_c, 'active', now())
  on conflict (tenant_id, school_id) do update set status = 'active', accepted_at = now();

  -- tenant_schools hanya mencatat sekolah binaan SPPG. Supaya akun ini juga bisa
  -- masuk sebagai guru, keanggotaannya di sekolah harus dicatat terpisah.
  insert into public.school_memberships (school_id, user_id, role, status)
  values (sekolah_a, uid, 'admin', 'active'),
         (sekolah_b, uid, 'admin', 'active'),
         (sekolah_c, uid, 'admin', 'active')
  on conflict (school_id, user_id) do update set status = 'active';

  ---------------------------------------------------------------------------
  -- 2. Menu siap pakai
  ---------------------------------------------------------------------------
  -- Menu A
  select id into menu_a from public.recipes where tenant_id = tid and name = 'Nasi Ayam Bumbu Kuning';
  if menu_a is null then
    insert into public.recipes (tenant_id, name, description, created_by)
    values (tid, 'Nasi Ayam Bumbu Kuning', 'Menu harian dengan lauk unggas dan sayur tumis.', uid)
    returning id into menu_a;

    insert into public.recipe_components
      (tenant_id, recipe_id, name, portion_grams, kcal, protein_g, carbs_g, fat_g,
       ingredients, allergens, allergen_state, nutrition_source, position)
    values
      (tid, menu_a, 'Nasi putih', 150, 195, 3.6, 42.9, 0.3,
       array['Beras','Air'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 1),
      (tid, menu_a, 'Ayam bumbu kuning', 60, 149, 16.2, 1.5, 8.6,
       array['Daging ayam','Kunyit','Bawang merah','Bawang putih','Santan'],
       array['Santan'], 'known', 'Perkiraan dapur, perlu ditinjau ahli gizi', 2),
      (tid, menu_a, 'Tumis buncis wortel', 70, 61, 1.6, 6.4, 3.2,
       array['Buncis','Wortel','Bawang putih','Minyak sayur'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 3),
      (tid, menu_a, 'Pisang', 100, 92, 1.0, 23.4, 0.5,
       array['Pisang'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 4);
  end if;

  -- Menu B
  select id into menu_b from public.recipes where tenant_id = tid and name = 'Nasi Telur Balado';
  if menu_b is null then
    insert into public.recipes (tenant_id, name, description, created_by)
    values (tid, 'Nasi Telur Balado', 'Menu hemat dengan sumber protein telur.', uid)
    returning id into menu_b;

    insert into public.recipe_components
      (tenant_id, recipe_id, name, portion_grams, kcal, protein_g, carbs_g, fat_g,
       ingredients, allergens, allergen_state, nutrition_source, position)
    values
      (tid, menu_b, 'Nasi putih', 150, 195, 3.6, 42.9, 0.3,
       array['Beras','Air'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 1),
      (tid, menu_b, 'Telur balado', 55, 118, 9.9, 2.4, 7.8,
       array['Telur ayam','Cabai merah','Bawang merah','Minyak sayur'],
       array['Telur'], 'known', 'Perkiraan dapur, perlu ditinjau ahli gizi', 2),
      (tid, menu_b, 'Sayur bayam bening', 80, 30, 2.4, 4.6, 0.4,
       array['Bayam','Jagung manis','Bawang merah'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 3),
      (tid, menu_b, 'Jeruk', 100, 47, 0.9, 11.8, 0.1,
       array['Jeruk'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 4);
  end if;

  -- Menu C
  select id into menu_c from public.recipes where tenant_id = tid and name = 'Nasi Ikan Tuna Suwir';
  if menu_c is null then
    insert into public.recipes (tenant_id, name, description, created_by)
    values (tid, 'Nasi Ikan Tuna Suwir', 'Menu dengan sumber protein ikan dan sayur campur.', uid)
    returning id into menu_c;

    insert into public.recipe_components
      (tenant_id, recipe_id, name, portion_grams, kcal, protein_g, carbs_g, fat_g,
       ingredients, allergens, allergen_state, nutrition_source, position)
    values
      (tid, menu_c, 'Nasi putih', 150, 195, 3.6, 42.9, 0.3,
       array['Beras','Air'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 1),
      (tid, menu_c, 'Ikan tuna suwir bumbu', 60, 108, 17.4, 1.2, 3.6,
       array['Ikan tuna','Bawang putih','Kemangi','Minyak sayur'],
       array['Ikan'], 'known', 'Perkiraan dapur, perlu ditinjau ahli gizi', 2),
      (tid, menu_c, 'Capcay sayur', 80, 68, 2.2, 7.8, 3.1,
       array['Sawi','Wortel','Kubis','Bawang putih','Minyak sayur'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 3),
      (tid, menu_c, 'Semangka', 120, 38, 0.7, 9.5, 0.2,
       array['Semangka'], array[]::text[], 'known',
       'Perkiraan dapur, perlu ditinjau ahli gizi', 4);
  end if;

  ---------------------------------------------------------------------------
  -- 3. Riwayat: satu produksi tiga hari lalu, dua kiriman yang sudah diterima
  ---------------------------------------------------------------------------
  select id into batch_lalu from public.batches where tenant_id = tid and code = 'BATCH-0001';
  if batch_lalu is null then
    masak := now() - interval '3 days' - interval '5 hours';

    insert into public.batches
      (tenant_id, code, recipe_id, production_date, status, notes,
       created_by, finalized_by, finalized_at)
    values (tid, 'BATCH-0001', menu_a, (now() - interval '3 days')::date, 'ready',
            'Produksi pagi.', uid, uid, masak)
    returning id into batch_lalu;

    insert into public.batch_components
      (tenant_id, batch_id, name, portions_produced, cooked_at, policy_id,
       duration_minutes_snapshot, warning_minutes_snapshot, consume_by,
       kcal, protein_g, carbs_g, fat_g, portion_grams,
       ingredients, allergens, allergen_state, nutrition_source)
    select tid, batch_lalu, rc.name, 240, masak, pid, dur, warn,
           masak + make_interval(mins => dur),
           rc.kcal, rc.protein_g, rc.carbs_g, rc.fat_g, rc.portion_grams,
           rc.ingredients, rc.allergens, rc.allergen_state, rc.nutrition_source
    from public.recipe_components rc
    where rc.tenant_id = tid and rc.recipe_id = menu_a
    order by rc.position;

    select id into komp_nasi  from public.batch_components where tenant_id = tid and batch_id = batch_lalu and name = 'Nasi putih';
    select id into komp_lauk  from public.batch_components where tenant_id = tid and batch_id = batch_lalu and name = 'Ayam bumbu kuning';
    select id into komp_sayur from public.batch_components where tenant_id = tid and batch_id = batch_lalu and name = 'Tumis buncis wortel';
    select id into komp_buah  from public.batch_components where tenant_id = tid and batch_id = batch_lalu and name = 'Pisang';

    -- Kiriman pertama: diterima seluruhnya
    insert into public.deliveries
      (tenant_id, school_id, code, status, scheduled_at, dispatched_at, completed_at,
       created_by, dispatched_by, idempotency_key)
    values (tid, sekolah_a, 'KRM-0001', 'completed',
            masak + interval '1 hour', masak + interval '1 hour',
            masak + interval '2 hours', uid, uid, 'seed-krm-0001')
    returning id into kirim_1;

    insert into public.qr_labels (tenant_id, delivery_id, token, issued_at)
    values (tid, kirim_1, encode(gen_random_bytes(16), 'hex'), masak + interval '1 hour');

    foreach komp_id in array array[komp_nasi, komp_lauk, komp_sayur, komp_buah]
    loop
      insert into public.delivery_items (tenant_id, delivery_id, batch_component_id, portions)
      values (tid, kirim_1, komp_id, 120)
      returning id into item_id;

      insert into public.receipts
        (tenant_id, delivery_id, delivery_item_id, school_id, received_by, received_at,
         accepted_portions, rejected_portions, idempotency_key)
      values (tid, kirim_1, item_id, sekolah_a, uid, masak + interval '2 hours',
              120, 0, 'seed-rcp-' || item_id::text);
    end loop;

    -- Kiriman kedua: ada porsi yang ditolak, supaya layar penerimaan tidak seragam
    insert into public.deliveries
      (tenant_id, school_id, code, status, scheduled_at, dispatched_at, completed_at,
       created_by, dispatched_by, idempotency_key)
    values (tid, sekolah_b, 'KRM-0002', 'completed',
            masak + interval '1 hour', masak + interval '1 hour',
            masak + interval '3 hours', uid, uid, 'seed-krm-0002')
    returning id into kirim_2;

    insert into public.qr_labels (tenant_id, delivery_id, token, issued_at)
    values (tid, kirim_2, encode(gen_random_bytes(16), 'hex'), masak + interval '1 hour');

    insert into public.delivery_items (tenant_id, delivery_id, batch_component_id, portions)
    values (tid, kirim_2, komp_nasi, 100)
    returning id into item_id;
    insert into public.receipts
      (tenant_id, delivery_id, delivery_item_id, school_id, received_by, received_at,
       accepted_portions, rejected_portions, idempotency_key)
    values (tid, kirim_2, item_id, sekolah_b, uid, masak + interval '3 hours',
            100, 0, 'seed-rcp-b1');

    insert into public.delivery_items (tenant_id, delivery_id, batch_component_id, portions)
    values (tid, kirim_2, komp_lauk, 100)
    returning id into item_id;
    insert into public.receipts
      (tenant_id, delivery_id, delivery_item_id, school_id, received_by, received_at,
       accepted_portions, rejected_portions, reason, condition_note, idempotency_key)
    values (tid, kirim_2, item_id, sekolah_b, uid, masak + interval '3 hours',
            94, 6, 'Wadah bocor saat perjalanan',
            'Enam porsi dipisahkan dan tidak dibagikan.', 'seed-rcp-b2');

    -- Satu insiden terbuka, terhubung ke kiriman kedua
    insert into public.incidents
      (tenant_id, delivery_id, school_id, reported_by, category, description,
       status, severity, reported_at)
    values (tid, kirim_2, sekolah_b, uid, 'quality',
            'Enam porsi lauk tiba dengan wadah bocor. Porsi tersebut tidak dibagikan ke siswa.',
            'open', 'medium', masak + interval '3 hours' + interval '10 minutes');
  end if;

  raise notice 'Selesai. Sekolah, menu, dan riwayat siap. Batch hari ini sengaja dikosongkan.';
end $$;
