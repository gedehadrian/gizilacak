import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import '../billing/billing_page.dart' show rupiah;

/// Biaya operasional SPPG dan ringkasannya. Angka yang sama dengan halaman
/// /app/keuangan di web, dari tabel yang sama.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  static const categories = {
    'ingredients': 'Bahan',
    'packaging': 'Kemasan',
    'transport': 'Transport',
    'labor': 'Tenaga kerja',
    'other': 'Lain-lain',
  };

  List<Map<String, dynamic>> items = const [];
  ({int expenses, int paidInvoices, int accepted, int rejected})? summary;
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
    final tenantId = session.current!.id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await session.api.expenses(tenantId);
      final totals = await session.api.financeSummary(tenantId);
      if (!mounted) return;
      setState(() {
        items = rows;
        summary = totals;
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

  Future<void> _add() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    var category = categories.keys.first;

    final confirmed = await showGlDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => GlDialog(
          title: const Text('Biaya baru'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              GlInput(
                controller: description,
                placeholder: 'Keterangan',
                autofocus: true,
              ),
              const SizedBox(height: 8),
              GlInput(
                controller: amount,
                placeholder: 'Nominal rupiah',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 88,
                child: GlChoicePicker(
                  itemExtent: 28,
                  scrollController: FixedExtentScrollController(
                    initialItem: categories.keys.toList().indexOf(category),
                  ),
                  onSelectedItemChanged: (i) =>
                      setDialog(() => category = categories.keys.elementAt(i)),
                  children: [
                    for (final label in categories.values)
                      Center(child: Text(label, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            GlDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            GlDialogAction(
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
      await session.api.createExpense(
        tenantId: session.current!.id,
        userId: session.user!.id,
        category: category,
        description: description.text,
        amountRp: int.tryParse(amount.text.trim().replaceAll('.', '')) ?? 0,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> expense) async {
    final picked = await showGlSheet<String>(
      context: context,
      builder: (ctx) => GlSheet(
        title: Text(expense['description'] as String? ?? 'Biaya'),
        message: const Text('Hanya biaya berstatus "posted" yang masuk ringkasan.'),
        actions: [
          GlSheetAction(
            onPressed: () => Navigator.pop(ctx, 'posted'),
            child: const Text('Tandai posted'),
          ),
          GlSheetAction(
            onPressed: () => Navigator.pop(ctx, 'draft'),
            child: const Text('Kembalikan ke draf'),
          ),
          GlSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, 'void'),
            child: const Text('Batalkan'),
          ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup'),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    try {
      await SessionScope.of(context).api.setExpenseStatus(
            tenantId: SessionScope.of(context).current!.id,
            id: expense['id'] as String,
            status: picked,
          );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = summary;
    final days = groupByDay(items, 'expense_date');

    return GlDetail(
      title: 'Keuangan',
      loading: loading && items.isEmpty && summary == null,
      trailing: GlCircleButton(
        icon: LucideIcons.plus,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _add,
      ),
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Biaya tercatat (posted)',
          value: totals == null ? '—' : rupiah(totals.expenses),
          footer: 'Biaya berstatus draf belum dihitung di sini.',
          chips: [
            if (totals != null)
              GlHeroChip(label: 'tagihan lunas', value: rupiah(totals.paidInvoices)),
          ],
        ),
        const SizedBox(height: Gl.stack),
        if (totals != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gl.stack),
            child: Row(
              children: [
                Expanded(
                  child: GlStatPill(
                    label: 'Porsi diterima',
                    value: '${totals.accepted}',
                  ),
                ),
                const SizedBox(width: Gl.gap),
                Expanded(
                  child: GlStatPill(
                    label: 'Porsi ditolak',
                    value: '${totals.rejected}',
                    tint: totals.rejected > 0 ? Gl.blush : Gl.fill,
                    foreground: totals.rejected > 0 ? Gl.blushInk : Gl.secondary,
                  ),
                ),
              ],
            ),
          ),
        if (items.isEmpty && !loading)
          GlEmpty(
            icon: LucideIcons.circleDollarSign,
            message: 'Belum ada biaya tercatat.',
            actionLabel: 'Catat biaya pertama',
            onAction: _add,
          )
        else
          for (final day in days) ...[
            GlSectionHead(day.label),
            for (final expense in day.rows)
              GlTile(
                leading: GlGlyph(
                  icon: LucideIcons.dollarSign,
                  tint: _tint(expense['status'] as String? ?? '').tint,
                  foreground: _tint(expense['status'] as String? ?? '').ink,
                ),
                title: expense['description'] as String? ?? 'Biaya',
                subtitle: categories[expense['category']] ?? expense['category'] as String?,
                value: rupiah(expense['amount_rp']),
                trailing: StatusChip(
                  _label(expense['status'] as String? ?? ''),
                  tone: _tone(expense['status'] as String? ?? ''),
                ),
                chevron: true,
                onTap: () => _changeStatus(expense),
              ),
            const SizedBox(height: Gl.stack - Gl.gap),
          ],
      ],
    );
  }

  static ChipTone _tone(String status) => switch (status) {
        'posted' => ChipTone.good,
        'draft' => ChipTone.warn,
        _ => ChipTone.neutral,
      };

  static ({Color tint, Color ink}) _tint(String status) => tintForTone(_tone(status));

  static String _label(String status) => switch (status) {
        'posted' => 'Posted',
        'draft' => 'Draf',
        'void' => 'Dibatalkan',
        _ => status,
      };
}
