import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import '../billing/billing_page.dart' show rupiah;
import 'plan_form.dart';

/// Konsol operator GiziLacak: SPPG terdaftar, tagihan lintas tenant, paket,
/// dan biaya platform. Hanya terbuka untuk pengguna di `platform_users`;
/// RLS yang menegakkannya, bukan layar ini.
class PlatformPage extends StatefulWidget {
  const PlatformPage({super.key});

  @override
  State<PlatformPage> createState() => _PlatformPageState();
}

class _PlatformPageState extends State<PlatformPage> {
  List<Map<String, dynamic>> tenants = const [];
  List<Map<String, dynamic>> invoices = const [];
  List<Map<String, dynamic>> plans = const [];
  List<Map<String, dynamic>> expenses = const [];
  bool loading = true;
  String? error;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope dibaca di dalam _load(), dan InheritedWidget
    // baru boleh dibaca setelah initState selesai.
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final t = await session.api.platformTenants();
      final i = await session.api.platformInvoices();
      final p = await session.api.platformPlans();
      final e = await session.api.platformExpenses();
      if (!mounted) return;
      setState(() {
        tenants = t;
        invoices = i;
        plans = p;
        expenses = e;
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  final Set<String> publishing = {};

  Future<void> _planForm([Map<String, dynamic>? plan]) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => PlanForm(plan: plan)),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _publish(Map<String, dynamic> plan, Map<String, dynamic> version) async {
    final id = version['id'] as String;
    if (publishing.contains(id)) return;
    final confirmed = await showCupertinoDialog<bool>(context: context, builder: (ctx) => CupertinoAlertDialog(
      title: Text('Terbitkan ${plan['name']} v${version['version']}?'),
      content: Text('${rupiah(version['price_rp'])} per bulan. Versi ini akan tersedia untuk langganan jika paket aktif.'),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terbitkan')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => publishing.add(id));
    try {
      await SessionScope.of(context).api.publishPlanVersion(id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    } finally {
      if (mounted) setState(() => publishing.remove(id));
    }
  }

  /// Memberi mitra uji coba langganan aktif tanpa tagihan. Bukan kelonggaran
  /// pada pemeriksaan langganan — pilot mendapat langganan sungguhan seharga
  /// nol, jadi kuota dan masa berlakunya tetap berlaku seperti biasa.
  Future<void> _grantPilot(Map<String, dynamic> tenant) async {
    final published = <Map<String, dynamic>>[
      for (final plan in plans)
        for (final version in _versions(plan))
          if (version['published_at'] != null)
            {...version, '_plan': plan['name']},
    ];
    if (published.isEmpty) {
      await showGlError(
        context,
        'Belum ada versi paket yang diterbitkan. Terbitkan satu lebih dulu.',
      );
      return;
    }

    final picked = await showCupertinoModalPopup<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Paket untuk ${tenant['name']}'),
        message: const Text(
          'Mitra uji coba tidak membayar, tapi kuota dan masa berlakunya tetap '
          'dihitung seperti pelanggan biasa.',
        ),
        actions: [
          for (final version in published)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, version),
              child: Text(
                "${version['_plan']} v${version['version']} · "
                "${version['delivery_limit']} kiriman",
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final reason = TextEditingController(text: 'Mitra uji coba lapangan');
    final months = TextEditingController(text: '4');
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Beri langganan pilot'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: months,
              placeholder: 'Berapa bulan',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            CupertinoTextField(controller: reason, placeholder: 'Alasan'),
            const SizedBox(height: 8),
            const Text(
              'Alasannya ikut tercatat di jejak audit.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Beri'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await SessionScope.of(context).api.grantPilotSubscription(
            tenantId: tenant['id'] as String,
            planVersionId: picked['id'] as String,
            months: int.tryParse(months.text.trim()) ?? 0,
            reason: reason.text,
          );
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _addExpense() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final category = TextEditingController(text: 'infrastruktur');
    var kind = 'fixed';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => CupertinoAlertDialog(
          title: const Text('Biaya platform'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: description,
                placeholder: 'Keterangan',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              CupertinoTextField(controller: category, placeholder: 'Kategori'),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: amount,
                placeholder: 'Nominal rupiah',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CupertinoSlidingSegmentedControl<String>(
                groupValue: kind,
                children: const {
                  'fixed': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('Tetap', style: TextStyle(fontSize: 12)),
                  ),
                  'variable': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('Variabel', style: TextStyle(fontSize: 12)),
                  ),
                },
                onValueChanged: (v) => setDialog(() => kind = v ?? kind),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = SessionScope.of(context);
    try {
      await session.api.createPlatformExpense(
        userId: session.user!.id,
        category: category.text,
        description: description.text,
        amountRp: int.tryParse(amount.text.trim().replaceAll('.', '')) ?? 0,
        kind: kind,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpaid = invoices.where((i) => i['status'] == 'open').toList();
    final paidTotal = invoices
        .where((i) => i['status'] == 'paid')
        .fold<int>(0, (sum, i) => sum + ((i['total_rp'] as num?)?.toInt() ?? 0));
    final expenseTotal = expenses
        .where((e) => e['status'] == 'posted')
        .fold<int>(0, (sum, e) => sum + ((e['amount_rp'] as num?)?.toInt() ?? 0));

    return GlDetail(
      title: 'Platform',
      subtitle: 'Operator GiziLacak',
      loading: loading && tenants.isEmpty,
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Pendapatan tercatat lunas',
          value: rupiah(paidTotal),
          footer: 'Dari ${invoices.length} tagihan seluruh SPPG.',
          chips: [
            GlHeroChip(label: 'SPPG', value: '${tenants.length}'),
            if (unpaid.isNotEmpty)
              GlHeroChip(label: 'tagihan terbuka', value: '${unpaid.length}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        Padding(
          padding: const EdgeInsets.only(bottom: Gl.stack),
          child: Row(
            children: [
              Expanded(
                child: GlStatPill(
                  label: 'Biaya platform',
                  value: rupiah(expenseTotal),
                  tint: Gl.blush,
                  foreground: Gl.blushInk,
                ),
              ),
              const SizedBox(width: Gl.gap),
              Expanded(
                child: GlStatPill(
                  label: 'Selisih',
                  value: rupiah(paidTotal - expenseTotal),
                  tint: paidTotal >= expenseTotal ? Gl.mint : Gl.amber,
                  foreground: paidTotal >= expenseTotal ? Gl.mintInk : Gl.amberInk,
                ),
              ),
            ],
          ),
        ),
        const GlSectionHead('SPPG terdaftar'),
        if (tenants.isEmpty)
          const GlEmpty(
            icon: CupertinoIcons.building_2_fill,
            message: 'Belum ada SPPG terdaftar.',
          )
        else
          for (final tenant in tenants.take(20))
            GlTile(
              leading: GlGlyph(
                icon: CupertinoIcons.building_2_fill,
                tint: tenant['status'] == 'active' ? Gl.lilac : Gl.fill,
                foreground: tenant['status'] == 'active' ? Gl.primary : Gl.tertiary,
              ),
              title: tenant['name'] as String? ?? 'SPPG',
              subtitle: tenant['sppg_code'] as String?,
              trailing: StatusChip(
                statusLabel(tenant['status'] as String? ?? ''),
                tone: toneForStatus(tenant['status'] as String? ?? ''),
              ),
              chevron: true,
              onTap: () => _grantPilot(tenant),
            ),
        const SizedBox(height: Gl.stack - Gl.gap),
        if (unpaid.isNotEmpty) ...[
          const GlSectionHead('Tagihan terbuka'),
          for (final invoice in unpaid.take(20))
            GlTile(
              leading: const GlGlyph(
                icon: CupertinoIcons.doc_text,
                tint: Gl.amber,
                foreground: Gl.amberInk,
              ),
              title: invoice['number'] as String? ?? 'Tagihan',
              subtitle: _tenantName(invoice['tenant_id'] as String?),
              value: rupiah(invoice['total_rp']),
            ),
          const SizedBox(height: Gl.stack - Gl.gap),
        ],
        GlSectionHead('Paket', actionLabel: 'Buat paket', onAction: () => _planForm()),
        for (final plan in plans)
          GlSection(
            header: displayPlanName(plan['name'] as String?, plan['code'] as String?),
            footer: displayPlanDescription(plan['description'] as String?),
            children: [
              for (final version in _versions(plan))
                GlRow(
                  title: 'v${version['version']}',
                  subtitle: '${version['delivery_limit']} kiriman · '
                      '${version['school_limit']} sekolah · '
                      '${version['staff_limit']} staf',
                  value: rupiah(version['price_rp']),
                  chevron: false,
                  trailing: version['published_at'] == null
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: publishing.contains(version['id']) ? null : () => _publish(plan, version),
                          child: Text(publishing.contains(version['id']) ? 'Menerbitkan…' : 'Terbitkan'),
                        )
                      : const StatusChip('Terbit', tone: ChipTone.good),
                ),
              if (_versions(plan).isEmpty)
                const GlRow(title: 'Belum ada versi', chevron: false),
              GlRow(title: 'Buat versi baru', subtitle: 'Periode 1 bulan', onTap: () => _planForm(plan)),
            ],
          ),
        GlSectionHead(
          'Biaya platform',
          actionLabel: 'Tambah',
          onAction: _addExpense,
        ),
        if (expenses.isEmpty)
          GlEmpty(
            icon: CupertinoIcons.money_dollar_circle,
            message: 'Belum ada biaya platform tercatat.',
            actionLabel: 'Catat biaya',
            onAction: _addExpense,
          )
        else
          for (final expense in expenses.take(20))
            GlTile(
              leading: GlGlyph(
                icon: CupertinoIcons.money_dollar,
                tint: expense['status'] == 'posted' ? Gl.mint : Gl.fill,
                foreground: expense['status'] == 'posted' ? Gl.mintInk : Gl.tertiary,
              ),
              title: expense['description'] as String? ?? 'Biaya',
              subtitle: '${expense['category']} · ${expense['kind']}',
              value: rupiah(expense['amount_rp']),
            ),

      ],
    );
  }

  List<Map<String, dynamic>> _versions(Map<String, dynamic> plan) {
    final rows = List<Map<String, dynamic>>.from(
      (plan['plan_versions'] as List?) ?? const [],
    );
    rows.sort((a, b) =>
        ((b['version'] as num?) ?? 0).compareTo((a['version'] as num?) ?? 0));
    return rows;
  }

  String? _tenantName(String? tenantId) {
    if (tenantId == null) return null;
    for (final tenant in tenants) {
      if (tenant['id'] == tenantId) return tenant['name'] as String?;
    }
    return null;
  }
}
