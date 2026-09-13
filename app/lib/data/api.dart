import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../state/session.dart';
import 'pg.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Satu baris muatan kiriman: komponen mana, berapa porsi.
class DeliveryLine {
  const DeliveryLine({
    required this.componentId,
    required this.portions,
    required this.label,
  });

  final String componentId;
  final int portions;

  /// Nama komponen, dipakai untuk menyusun pesan kesalahan yang bisa dibaca.
  final String label;
}

class Api {
  Api(this.sb);
  final SupabaseClient sb;

  Never _fail(PostgrestException e) => throw ApiException(mapPgError(e.message));

  Future<({List<OrgScope> tenants, List<OrgScope> schools})> memberships(String userId) async {
    final tenantsRes = await sb
        .from('tenant_memberships')
        .select('tenant_id, role, status, tenants(name, sppg_code, status)')
        .eq('user_id', userId)
        .eq('status', 'active');
    final schoolsRes = await sb
        .from('school_memberships')
        .select('school_id, role, status, schools(name, school_code, status)')
        .eq('user_id', userId)
        .eq('status', 'active');

    final tenants = <OrgScope>[];
    for (final row in tenantsRes as List) {
      final t = row['tenants'] as Map<String, dynamic>?;
      if (t == null) continue;
      tenants.add(OrgScope(
        kind: OrgKind.tenant,
        id: row['tenant_id'] as String,
        name: t['name'] as String,
        code: t['sppg_code'] as String? ?? '',
        role: row['role'] as String,
      ));
    }
    final schools = <OrgScope>[];
    for (final row in schoolsRes as List) {
      final s = row['schools'] as Map<String, dynamic>?;
      if (s == null) continue;
      schools.add(OrgScope(
        kind: OrgKind.school,
        id: row['school_id'] as String,
        name: s['name'] as String,
        code: s['school_code'] as String? ?? '',
        role: row['role'] as String,
      ));
    }
    return (tenants: tenants, schools: schools);
  }

  Future<String> onboardTenant({
    required String name,
    required String code,
    required String address,
    required String billingEmail,
  }) async {
    final res = await sb.rpc('onboard_tenant', params: {
      '_name': name,
      '_sppg_code': code,
      '_address': address,
      '_billing_email': billingEmail,
    });
    return res as String;
  }

  Future<String> onboardSchool({
    required String name,
    required String code,
    required String address,
  }) async {
    final res = await sb.rpc('onboard_school', params: {
      '_name': name,
      '_school_code': code,
      '_address': address,
    });
    return res as String;
  }

  /// Kebijakan konsumsi yang sedang berlaku. Tanpa ini batch tidak bisa dibuat.
  Future<Map<String, dynamic>?> activePolicy(String tenantId) async {
    final res = await sb
        .from('consumption_policies')
        .select('id, version, name, duration_minutes, warning_minutes, source_note, effective_from')
        .eq('tenant_id', tenantId)
        .isFilter('retired_at', null)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> policyHistory(String tenantId) async {
    final res = await sb
        .from('consumption_policies')
        .select('id, version, name, duration_minutes, warning_minutes, source_note, effective_from, retired_at')
        .eq('tenant_id', tenantId)
        .order('version', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Menerbitkan versi baru dan memensiunkan yang lama, sama seperti
  /// POST /api/policies di web.
  Future<void> savePolicy({
    required String tenantId,
    required String userId,
    required String name,
    required int durationMinutes,
    required int warningMinutes,
    required String sourceNote,
  }) async {
    if (name.trim().length < 3) {
      throw ApiException('Nama kebijakan minimal 3 huruf.');
    }
    if (durationMinutes <= 0 || warningMinutes <= 0) {
      throw ApiException('Durasi dan peringatan harus lebih dari 0 menit.');
    }
    if (warningMinutes >= durationMinutes) {
      throw ApiException('Peringatan harus lebih singkat dari durasi konsumsi.');
    }
    if (sourceNote.trim().length < 3) {
      throw ApiException('Catatan sumber wajib diisi, minimal 3 huruf.');
    }

    try {
      final last = await sb
          .from('consumption_policies')
          .select('version')
          .eq('tenant_id', tenantId)
          .order('version', ascending: false)
          .limit(1)
          .maybeSingle();
      final version = ((last?['version'] as num?)?.toInt() ?? 0) + 1;

      await sb
          .from('consumption_policies')
          .update({'retired_at': DateTime.now().toUtc().toIso8601String()})
          .eq('tenant_id', tenantId)
          .isFilter('retired_at', null);

      await sb.from('consumption_policies').insert({
        'tenant_id': tenantId,
        'version': version,
        'name': name.trim(),
        'duration_minutes': durationMinutes,
        'warning_minutes': warningMinutes,
        'source_note': sourceNote.trim(),
        'approved_by': userId,
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  // --- Menu / resep -------------------------------------------------------

  Future<List<Map<String, dynamic>>> recipes(String tenantId) async {
    final res = await sb
        .from('recipes')
        .select('id, name, description, archived_at, recipe_components(id)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> recipe(String tenantId, String id) async {
    final res = await sb
        .from('recipes')
        .select('*, recipe_components(*)')
        .eq('tenant_id', tenantId)
        .eq('id', id)
        .maybeSingle();
    if (res == null) throw ApiException('Menu tidak ditemukan.');
    return Map<String, dynamic>.from(res);
  }

  Future<String> createRecipe({
    required String tenantId,
    required String userId,
    required String name,
    String? description,
  }) async {
    if (name.trim().isEmpty) throw ApiException('Nama menu wajib diisi.');
    try {
      final res = await sb
          .from('recipes')
          .insert({
            'tenant_id': tenantId,
            'name': name.trim(),
            'description': description?.trim(),
            'created_by': userId,
          })
          .select('id')
          .single();
      return res['id'] as String;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<void> updateRecipe({
    required String tenantId,
    required String id,
    required String name,
    String? description,
    bool? archived,
  }) async {
    if (name.trim().isEmpty) throw ApiException('Nama menu wajib diisi.');
    try {
      await sb
          .from('recipes')
          .update({
            'name': name.trim(),
            'description': description?.trim(),
            if (archived != null)
              'archived_at': archived ? DateTime.now().toUtc().toIso8601String() : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .eq('id', id);
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  /// Menyimpan satu komponen resep. [id] null berarti menambah baru.
  Future<void> saveRecipeComponent({
    required String tenantId,
    required String recipeId,
    String? id,
    required String name,
    num? portionGrams,
    num? kcal,
    num? proteinG,
    num? carbsG,
    num? fatG,
    List<String> ingredients = const [],
    List<String> allergens = const [],
    bool allergensChecked = false,
    String? nutritionSource,
    int position = 0,
  }) async {
    if (name.trim().isEmpty) throw ApiException('Nama komponen wajib diisi.');
    final payload = {
      'tenant_id': tenantId,
      'recipe_id': recipeId,
      'name': name.trim(),
      'portion_grams': portionGrams,
      'kcal': kcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'ingredients': ingredients,
      'allergens': allergens,
      'allergen_state': allergensChecked ? 'known' : 'unknown',
      'nutrition_source': nutritionSource?.trim(),
      'position': position,
    };
    try {
      if (id == null) {
        await sb.from('recipe_components').insert(payload);
      } else {
        await sb
            .from('recipe_components')
            .update({...payload, 'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('tenant_id', tenantId)
            .eq('id', id);
      }
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<void> deleteRecipeComponent({
    required String tenantId,
    required String id,
  }) async {
    try {
      await sb.from('recipe_components').delete().eq('tenant_id', tenantId).eq('id', id);
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<List<Map<String, dynamic>>> batches(String tenantId) async {
    final res = await sb
        .from('batches')
        .select('id, code, status, production_date, created_at, notes')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(80);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> batch(String tenantId, String id) async {
    final res = await sb
        .from('batches')
        .select('*, batch_components(*)')
        .eq('tenant_id', tenantId)
        .eq('id', id)
        .maybeSingle();
    if (res == null) throw ApiException('Batch tidak ditemukan.');
    return Map<String, dynamic>.from(res);
  }

  /// Membuat batch. Kalau [recipeId] diisi, komponen resep beserta gizinya
  /// disalin ke batch — sumber data yang dibaca siswa saat memindai QR.
  /// Perilakunya mengikuti POST /api/batches di web.
  Future<String> createBatch({
    required String tenantId,
    required String userId,
    required DateTime productionDate,
    required int portions,
    String? notes,
    String? recipeId,
    Map<String, int>? portionsByComponent,
  }) async {
    final policy = await sb
        .from('consumption_policies')
        .select('id, duration_minutes, warning_minutes')
        .eq('tenant_id', tenantId)
        .isFilter('retired_at', null)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();
    if (policy == null) {
      throw ApiException('Belum ada kebijakan konsumsi aktif.');
    }

    final ymd =
        '${productionDate.year.toString().padLeft(4, '0')}-${productionDate.month.toString().padLeft(2, '0')}-${productionDate.day.toString().padLeft(2, '0')}';
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    final code = 'BCH-${ymd.replaceAll('-', '')}-${suffix.substring(suffix.length - 6)}';

    var comps = <Map<String, dynamic>>[
      {'name': 'Komponen utama'},
    ];
    if (recipeId != null) {
      final recipeComps = await sb
          .from('recipe_components')
          .select('*')
          .eq('tenant_id', tenantId)
          .eq('recipe_id', recipeId)
          .order('position');
      final rows = List<Map<String, dynamic>>.from(recipeComps as List);
      if (rows.isNotEmpty) comps = rows;
    }

    /// Porsi tiap komponen boleh berbeda — dapur bisa memasak 480 nasi tapi
    /// 240 ayam A dan 240 ayam B. Tanpa rincian, semuanya memakai [portions].
    int portionsFor(Map<String, dynamic> component) {
      final id = component['id'] as String?;
      final value = id == null ? null : portionsByComponent?[id];
      return value ?? portions;
    }

    for (final c in comps) {
      if (portionsFor(c) <= 0) {
        throw ApiException(
          'Porsi ${c['name'] ?? 'komponen'} harus lebih dari 0.',
        );
      }
    }

    try {
      final inserted = await sb
          .from('batches')
          .insert({
            'tenant_id': tenantId,
            'code': code,
            'recipe_id': recipeId,
            'production_date': ymd,
            'notes': notes,
            'created_by': userId,
            'status': 'draft',
          })
          .select('id')
          .single();

      final batchId = inserted['id'] as String;
      await sb.from('batch_components').insert([
        for (final c in comps)
          {
            'tenant_id': tenantId,
            'batch_id': batchId,
            'name': c['name'],
            'portions_produced': portionsFor(c),
            'policy_id': policy['id'],
            'duration_minutes_snapshot': policy['duration_minutes'],
            'warning_minutes_snapshot': policy['warning_minutes'],
            'kcal': c['kcal'],
            'protein_g': c['protein_g'],
            'carbs_g': c['carbs_g'],
            'fat_g': c['fat_g'],
            'portion_grams': c['portion_grams'],
            'ingredients': c['ingredients'] ?? <String>[],
            'allergens': c['allergens'] ?? <String>[],
            'allergen_state': c['allergen_state'] ?? 'unknown',
            'nutrition_source': c['nutrition_source'],
          },
      ]);
      return batchId;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<void> markCooked({
    required String tenantId,
    required String componentId,
    required DateTime cookedAt,
  }) async {
    final comp = await sb
        .from('batch_components')
        .select('id, duration_minutes_snapshot')
        .eq('id', componentId)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    if (comp == null) throw ApiException('Komponen tidak ditemukan.');
    final mins = (comp['duration_minutes_snapshot'] as num).toInt();
    final consumeBy = cookedAt.add(Duration(minutes: mins));
    await sb.from('batch_components').update({
      'cooked_at': cookedAt.toUtc().toIso8601String(),
      'consume_by': consumeBy.toUtc().toIso8601String(),
    }).eq('id', componentId);
  }

  Future<void> finalizeBatch(String batchId) async {
    try {
      await sb.rpc('finalize_batch', params: {'_batch_id': batchId});
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<List<Map<String, dynamic>>> deliveries({String? tenantId, String? schoolId}) async {
    var q = sb.from('deliveries').select(
          'id, code, status, school_id, tenant_id, dispatched_at, created_at, schools(name)',
        );
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final res = await q.order('created_at', ascending: false).limit(80);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> delivery(String id) async {
    final res = await sb
        .from('deliveries')
        .select(
          '*, delivery_items(id, portions, batch_component_id, batch_components(name)), qr_labels(token, revoked_at), receipts(delivery_item_id, accepted_portions, rejected_portions), schools(name)',
        )
        .eq('id', id)
        .maybeSingle();
    if (res == null) throw ApiException('Kiriman tidak ditemukan.');
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> linkedSchools(String tenantId) async {
    final res = await sb
        .from('tenant_schools')
        .select('id, status, school_id, schools(name, school_code)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> pendingSchoolLinks(String schoolId) async {
    final res = await sb
        .from('tenant_schools')
        .select('id, status, tenant_id, tenants(name, sppg_code)')
        .eq('school_id', schoolId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> acceptSchoolLink(String linkId) async {
    await sb.from('tenant_schools').update({
      'status': 'active',
      'accepted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', linkId);
  }

  Future<void> linkOwnSchool({required String tenantId, required String schoolId}) async {
    await sb.from('tenant_schools').insert({
      'tenant_id': tenantId,
      'school_id': schoolId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> readyComponents(String tenantId) async {
    final res = await sb
        .from('batch_components')
        .select('id, name, portions_produced, batches!inner(id, code, status, tenant_id)')
        .eq('tenant_id', tenantId)
        .eq('batches.status', 'ready');
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Membuat draf kiriman berisi satu atau lebih komponen.
  ///
  /// Satu kiriman ke satu sekolah lazimnya memuat beberapa komponen sekaligus —
  /// nasi, lauk, dan sayur — dan semuanya berbagi satu kode QR.
  Future<String> createDelivery({
    required String tenantId,
    required String schoolId,
    required List<DeliveryLine> items,
  }) async {
    if (items.isEmpty) {
      throw ApiException('Tambahkan minimal satu komponen ke kiriman.');
    }
    final seen = <String>{};
    for (final line in items) {
      if (line.portions <= 0) {
        throw ApiException('Porsi ${line.label} harus lebih dari 0.');
      }
      if (!seen.add(line.componentId)) {
        throw ApiException(
          '${line.label} ditambahkan dua kali. Gabungkan porsinya jadi satu baris.',
        );
      }
    }

    final key = '${tenantId}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final res = await sb.rpc('create_delivery_draft', params: {
        '_tenant_id': tenantId,
        '_school_id': schoolId,
        '_items': [
          for (final line in items)
            {'batch_component_id': line.componentId, 'portions': line.portions},
        ],
        '_idempotency_key': key,
      });
      return res as String;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<String> dispatch(String deliveryId) async {
    try {
      final res = await sb.rpc('dispatch_delivery', params: {'_delivery_id': deliveryId});
      return res as String;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<void> submitReceipt({
    required String deliveryItemId,
    required int accepted,
    required int rejected,
    String reason = '',
    String note = '',
  }) async {
    try {
      await sb.rpc('submit_receipt', params: {
        '_delivery_item_id': deliveryItemId,
        '_accepted': accepted,
        '_rejected': rejected,
        '_reason': reason,
        '_note': note,
        '_idempotency_key': '${deliveryItemId}_${DateTime.now().microsecondsSinceEpoch}',
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  // --- Platform (operator GiziLacak) --------------------------------------

  /// `pu_select` hanya mengembalikan baris milik sendiri dan hanya kalau aktif,
  /// jadi kembalian tidak kosong berarti pengguna ini operator platform.
  Future<bool> isPlatformAdmin(String userId) async {
    final res = await sb
        .from('platform_users')
        .select('active')
        .eq('user_id', userId)
        .eq('active', true)
        .maybeSingle();
    return res != null;
  }

  Future<List<Map<String, dynamic>>> platformTenants() async {
    final res = await sb
        .from('tenants')
        .select('id, name, sppg_code, status, created_at')
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> platformInvoices() async {
    final res = await sb
        .from('invoices')
        .select('id, number, status, total_rp, issued_at, due_at, tenant_id')
        .order('issued_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> platformPlans() async {
    final res = await sb
        .from('plans')
        .select('id, code, name, description, active, plan_versions(id, version, price_rp, staff_limit, school_limit, delivery_limit, published_at)')
        .order('created_at');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createPlan({required String code, required String name,
      required String description, required bool active}) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(code.trim())) {
      throw ApiException('Kode memakai huruf kecil, angka, garis bawah atau tanda hubung.');
    }
    if (name.trim().isEmpty) throw ApiException('Nama paket wajib diisi.');
    try {
      await sb.from('plans').insert({'code': code.trim(), 'name': name.trim(),
        'description': description.trim(), 'active': active});
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw ApiException('Kode paket sudah dipakai.');
      _fail(e);
    }
  }

  Future<void> createPlanVersion({required String planId, required int priceRp,
      required int staffLimit, required int schoolLimit, required int deliveryLimit}) async {
    if (priceRp < 0 || priceRp > 9007199254740991) throw ApiException('Harga tidak valid.');
    if ([staffLimit, schoolLimit, deliveryLimit].any((n) => n <= 0 || n > 2147483647)) {
      throw ApiException('Batas staf, sekolah dan kiriman harus berupa bilangan bulat positif.');
    }
    // Retry only a version collision from another operator; never overwrite it.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final last = await sb.from('plan_versions').select('version')
            .eq('plan_id', planId).order('version', ascending: false).limit(1).maybeSingle();
        await sb.from('plan_versions').insert({
          'plan_id': planId, 'version': ((last?['version'] as num?)?.toInt() ?? 0) + 1,
          'price_rp': priceRp, 'period_months': 1, 'staff_limit': staffLimit,
          'school_limit': schoolLimit, 'delivery_limit': deliveryLimit,
        });
        return;
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          if (attempt < 2) continue;
          throw ApiException('Versi berubah bersamaan. Muat ulang dan coba lagi.');
        }
        _fail(e);
      }
    }
  }

  Future<void> publishPlanVersion(String id) async {
    try {
      final row = await sb.from('plan_versions')
          .update({'published_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id).isFilter('published_at', null).select('id').maybeSingle();
      if (row == null) throw ApiException('Versi sudah terbit atau tidak dapat diubah. Muat ulang daftar paket.');
    } on PostgrestException catch (e) { _fail(e); }
  }

  /// Memberi SPPG langganan aktif tanpa tagihan, untuk mitra uji coba.
  ///
  /// Bukan pengecualian pada pemeriksaan langganan: pilot mendapat langganan
  /// sungguhan seharga nol, lengkap dengan kuota dan masa berlaku, sehingga
  /// uji coba lapangan menguji sistem yang sebenarnya. Hanya operator platform
  /// yang boleh, dan setiap pemberian tercatat di jejak audit.
  Future<void> grantPilotSubscription({
    required String tenantId,
    required String planVersionId,
    required int months,
    required String reason,
  }) async {
    if (months < 1 || months > 24) {
      throw ApiException('Masa berlaku pilot antara 1 dan 24 bulan.');
    }
    if (reason.trim().length < 3) {
      throw ApiException('Tulis alasan pemberian pilot, minimal 3 huruf.');
    }
    try {
      await sb.rpc('grant_pilot_subscription', params: {
        '_tenant_id': tenantId,
        '_plan_version_id': planVersionId,
        '_months': months,
        '_reason': reason.trim(),
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<List<Map<String, dynamic>>> platformExpenses() async {
    final res = await sb
        .from('platform_expenses')
        .select('id, category, description, amount_rp, incurred_on, kind, status')
        .order('incurred_on', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createPlatformExpense({
    required String userId,
    required String category,
    required String description,
    required int amountRp,
    required String kind,
    DateTime? date,
  }) async {
    if (description.trim().isEmpty) throw ApiException('Keterangan wajib diisi.');
    final when = date ?? DateTime.now();
    try {
      await sb.from('platform_expenses').insert({
        'category': category.trim().isEmpty ? 'other' : category.trim(),
        'description': description.trim(),
        'amount_rp': amountRp,
        'incurred_on':
            '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}',
        'kind': kind,
        'status': 'draft',
        'created_by': userId,
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  // --- Keuangan -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> expenses(String tenantId) async {
    final res = await sb
        .from('tenant_expenses')
        .select('id, category, description, amount_rp, expense_date, status, batch_id')
        .eq('tenant_id', tenantId)
        .order('expense_date', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createExpense({
    required String tenantId,
    required String userId,
    required String category,
    required String description,
    required int amountRp,
    DateTime? date,
  }) async {
    if (description.trim().isEmpty) throw ApiException('Keterangan biaya wajib diisi.');
    if (amountRp < 0) throw ApiException('Nominal tidak boleh negatif.');
    final when = date ?? DateTime.now();
    try {
      await sb.from('tenant_expenses').insert({
        'tenant_id': tenantId,
        'category': category,
        'description': description.trim(),
        'amount_rp': amountRp,
        'expense_date':
            '${when.year.toString().padLeft(4, '0')}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}',
        'status': 'draft',
        'created_by': userId,
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  /// Mengubah status biaya. `posted` berarti ikut dihitung di ringkasan.
  Future<void> setExpenseStatus({
    required String tenantId,
    required String id,
    required String status,
  }) async {
    try {
      await sb
          .from('tenant_expenses')
          .update({
            'status': status,
            'posted_at': status == 'posted'
                ? DateTime.now().toUtc().toIso8601String()
                : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .eq('id', id);
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  /// Angka ringkas untuk layar Keuangan, dihitung dari tabel yang sama seperti
  /// halaman /app/keuangan di web.
  Future<({int expenses, int paidInvoices, int accepted, int rejected})>
      financeSummary(String tenantId) async {
    final expenseRows = await sb
        .from('tenant_expenses')
        .select('amount_rp, status')
        .eq('tenant_id', tenantId)
        .eq('status', 'posted');
    final invoiceRows = await sb
        .from('invoices')
        .select('total_rp, status')
        .eq('tenant_id', tenantId)
        .eq('status', 'paid');
    final receiptRows = await sb
        .from('receipts')
        .select('accepted_portions, rejected_portions')
        .eq('tenant_id', tenantId);

    int sum(List rows, String field) => rows.fold<int>(
          0,
          (total, row) => total + (((row as Map)[field] as num?)?.toInt() ?? 0),
        );

    return (
      expenses: sum(expenseRows as List, 'amount_rp'),
      paidInvoices: sum(invoiceRows as List, 'total_rp'),
      accepted: sum(receiptRows as List, 'accepted_portions'),
      rejected: sum(receiptRows as List, 'rejected_portions'),
    );
  }

  // --- Insiden ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> incidents({
    String? tenantId,
    String? schoolId,
  }) async {
    var q = sb.from('incidents').select(
          'id, category, description, status, severity, reported_at, resolved_at, '
          'resolution, delivery_id, deliveries(code), schools(name)',
        );
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final res = await q.order('reported_at', ascending: false).limit(80);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> createIncident({
    required String tenantId,
    required String schoolId,
    required String deliveryId,
    required String userId,
    required String category,
    required String severity,
    required String description,
  }) async {
    if (description.trim().length < 5) {
      throw ApiException('Uraian insiden minimal 5 huruf.');
    }
    try {
      await sb.from('incidents').insert({
        'tenant_id': tenantId,
        'school_id': schoolId,
        'delivery_id': deliveryId,
        'reported_by': userId,
        'category': category,
        'severity': severity,
        'description': description.trim(),
        'status': 'open',
      });
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  /// Hanya owner/manager SPPG yang boleh menutup insiden (`inc_upd`).
  Future<void> setIncidentStatus({
    required String tenantId,
    required String id,
    required String status,
    String? resolution,
  }) async {
    try {
      await sb
          .from('incidents')
          .update({
            'status': status,
            'resolution': resolution?.trim(),
            'resolved_at': status == 'resolved' || status == 'closed'
                ? DateTime.now().toUtc().toIso8601String()
                : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .eq('id', id);
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  // --- Jejak audit --------------------------------------------------------

  Future<List<Map<String, dynamic>>> auditLogs(String tenantId) async {
    final res = await sb
        .from('audit_logs')
        .select('id, action, entity_type, entity_id, occurred_at, actor_id, reason')
        .eq('tenant_id', tenantId)
        .order('occurred_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // --- Tim & undangan -----------------------------------------------------

  /// Hanya profil sendiri yang boleh dibaca (`profiles_select`), jadi daftar
  /// anggota menampilkan peran dan status, bukan nama orang lain.
  Future<List<Map<String, dynamic>>> tenantMembers(String tenantId) async {
    final res = await sb
        .from('tenant_memberships')
        .select('user_id, role, status, created_at')
        .eq('tenant_id', tenantId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> schoolMembers(String schoolId) async {
    final res = await sb
        .from('school_memberships')
        .select('user_id, role, status, created_at')
        .eq('school_id', schoolId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> invitations({
    String? tenantId,
    String? schoolId,
  }) async {
    var q = sb
        .from('invitations')
        .select('id, email, role, expires_at, accepted_at, revoked_at, created_at');
    if (tenantId != null) q = q.eq('tenant_id', tenantId);
    if (schoolId != null) q = q.eq('school_id', schoolId);
    final res = await q.order('created_at', ascending: false).limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Membuat undangan dan mengembalikan token mentahnya. Yang disimpan hanya
  /// SHA-256 dari token itu, sama seperti POST /api/invitations di web, jadi
  /// token ini hanya bisa dilihat sekali — saat dibuat.
  Future<String> createInvitation({
    String? tenantId,
    String? schoolId,
    required String email,
    required String role,
    required String invitedBy,
  }) async {
    final target = email.trim().toLowerCase();
    if (!target.contains('@') || target.length < 5) {
      throw ApiException('Email undangan tidak valid.');
    }
    final token = _randomToken();
    final hash = sha256.convert(utf8.encode(token)).toString();

    try {
      await sb.from('invitations').insert({
        'tenant_id': ?tenantId,
        'school_id': ?schoolId,
        'email': target,
        'role': role,
        'token_hash': hash,
        'expires_at':
            DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
        'invited_by': invitedBy,
      });
      return token;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<void> revokeInvitation(String id) async {
    try {
      await sb
          .from('invitations')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  /// Menerima undangan. Menerima token mentah atau tautan undangan penuh —
  /// staf biasanya menyalin seluruh URL dari email.
  Future<void> acceptInvitation(String raw) async {
    final token = _tokenFrom(raw);
    if (token.length < 16) {
      throw ApiException('Token undangan tidak lengkap.');
    }
    final hash = sha256.convert(utf8.encode(token)).toString();
    try {
      await sb.rpc('accept_invitation', params: {'_token_hash': hash});
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  static String _tokenFrom(String raw) {
    final value = raw.trim();
    if (!value.contains('/')) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.pathSegments.isEmpty) return value;
    return uri.pathSegments.last;
  }

  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // --- Langganan & tagihan ------------------------------------------------

  /// Langganan terakhir, aktif atau tidak, supaya app bisa menampilkan periode
  /// yang sudah lewat dan bukan sekadar "belum aktif".
  Future<Map<String, dynamic>?> latestSubscription(String tenantId) async {
    final res = await sb
        .from('subscriptions')
        .select('id, status, period_start, period_end')
        .eq('tenant_id', tenantId)
        .order('period_end', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  /// Paket yang boleh dibeli SPPG. RLS sudah menyaring versi yang belum terbit,
  /// tapi tetap disaring di sini supaya maksudnya terbaca dari kode.
  Future<List<Map<String, dynamic>>> availablePlans() async {
    final res = await sb
        .from('plans')
        .select(
          'id, code, name, description, active, '
          'plan_versions(id, version, price_rp, staff_limit, school_limit, delivery_limit, published_at)',
        )
        .eq('active', true)
        .order('created_at');

    final plans = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(res as List)) {
      final versions = List<Map<String, dynamic>>.from(
        (row['plan_versions'] as List?) ?? const [],
      ).where((v) => v['published_at'] != null).toList()
        ..sort((a, b) =>
            ((b['version'] as num?) ?? 0).compareTo((a['version'] as num?) ?? 0));
      if (versions.isEmpty) continue;
      plans.add({...row, 'plan_versions': versions});
    }
    return plans;
  }

  /// Menerbitkan tagihan untuk sebuah versi paket, lalu dibayar lewat Midtrans.
  ///
  /// Harga diambil server dari katalog yang sudah terbit — klien hanya menunjuk
  /// versi paketnya, tidak pernah mengirim nominal. Hanya peran `owner` dan
  /// `finance` yang diizinkan RPC ini.
  Future<String> createInvoiceFromPlan({
    required String tenantId,
    required String planVersionId,
    required bool renewal,
  }) async {
    // Kunci idempotensi bergranularitas menit: ketukan ganda menghasilkan
    // tagihan yang sama, tapi pembelian berikutnya di lain waktu tetap bisa.
    final minute = DateTime.now().toUtc().toIso8601String().substring(0, 16);
    final key = '${tenantId}_${planVersionId}_$minute';
    try {
      final res = await sb.rpc('create_invoice_from_plan', params: {
        '_tenant_id': tenantId,
        '_plan_version_id': planVersionId,
        '_purpose': renewal ? 'renewal' : 'initial',
        '_idempotency_key': key,
      });
      return res as String;
    } on PostgrestException catch (e) {
      _fail(e);
    }
  }

  Future<List<Map<String, dynamic>>> invoices(String tenantId) async {
    final res = await sb
        .from('invoices')
        .select('id, number, status, total_rp, issued_at, due_at, service_start, service_end')
        .eq('tenant_id', tenantId)
        .order('issued_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> invoice(String tenantId, String id) async {
    final res = await sb
        .from('invoices')
        .select('*, invoice_lines(*), payments(id, status, checkout_url, order_id, amount_rp, created_at)')
        .eq('tenant_id', tenantId)
        .eq('id', id)
        .maybeSingle();
    if (res == null) throw ApiException('Tagihan tidak ditemukan.');
    return Map<String, dynamic>.from(res);
  }

  /// Kuota pemakaian periode berjalan — dipakai untuk memperingatkan sebelum
  /// dispatch ditolak karena `quota_exceeded`.
  Future<List<Map<String, dynamic>>> usage(String tenantId) async {
    final res = await sb
        .from('usage_counters')
        .select('metric, used, limit_snapshot, period_start, period_end')
        .eq('tenant_id', tenantId)
        .order('period_start', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Meminta server membuat transaksi Midtrans dan mengembalikan tautan bayar.
  ///
  /// Ini satu-satunya hal yang tidak bisa dikerjakan app sendiri: pembuatan
  /// transaksi Snap wajib memakai MIDTRANS_SERVER_KEY, yang tidak boleh ada di
  /// client. App hanya mengirim token Supabase-nya dan menerima sebuah URL.
  Future<String> startCheckout({
    required String tenantId,
    required String invoiceId,
  }) async {
    final token = sb.auth.currentSession?.accessToken;
    if (token == null) throw ApiException('Sesi berakhir. Masuk ulang untuk melanjutkan.');

    final uri = Uri.parse('${AppConfig.webAppUrl}/api/invoices/$invoiceId/checkout');
    late final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'x-gzl-tenant': tenantId,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak bisa menghubungi server pembayaran. Cek koneksi.');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Server pembayaran mengirim jawaban yang tidak dikenali.');
    }

    if (res.statusCode >= 400) {
      final error = body['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw ApiException(message ?? 'Pembayaran tidak bisa dimulai.');
    }

    final url = body['redirectUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw ApiException('Server tidak mengirim tautan pembayaran.');
    }
    return url;
  }

  Future<Map<String, dynamic>?> activeSubscription(String tenantId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final res = await sb
        .from('subscriptions')
        .select('id, status, period_start, period_end')
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .lte('period_start', now)
        .gt('period_end', now)
        .order('period_end', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }
}
