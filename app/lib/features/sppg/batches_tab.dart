import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'batch_page.dart';
import 'new_batch_sheet.dart';

/// Asks for the one number a new batch needs, creates it, and opens it.
/// Shared by the Produksi tab and the shortcut on Hari ini.
Future<void> startNewBatch(BuildContext context) async {
  final draft = await Navigator.of(context, rootNavigator: true).push<NewBatchDraft>(
    CupertinoPageRoute(fullscreenDialog: true, builder: (_) => const NewBatchSheet()),
  );
  if (draft == null || !context.mounted) return;

  final session = SessionScope.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  try {
    final id = await session.api.createBatch(
      tenantId: session.current!.id,
      userId: session.user!.id,
      productionDate: DateTime.now(),
      portions: draft.portions,
      recipeId: draft.recipeId,
      portionsByComponent: draft.portionsByComponent,
    );
    await navigator.push(
      CupertinoPageRoute(builder: (_) => BatchPage(batchId: id)),
    );
  } on ApiException catch (e) {
    if (context.mounted) await showGlError(context, e.message);
  }
}

class BatchesTab extends StatefulWidget {
  const BatchesTab({super.key});

  @override
  State<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<BatchesTab> {
  List<Map<String, dynamic>> items = const [];
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
      final data = await session.api.batches(session.current!.id);
      if (mounted) {
        setState(() {
          items = data;
          loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Future<void> _open(String batchId) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => BatchPage(batchId: batchId)),
    );
    await _load();
  }

  Future<void> _create() async {
    await startNewBatch(context);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = groupByDay(items, 'production_date');
    final ready = items.where((b) => b['status'] == 'ready').length;
    final draft = items.where((b) => b['status'] == 'draft').length;

    return GlSliver(
      title: 'Produksi',
      onRefresh: _load,
      trailing: GlCircleButton(
        icon: LucideIcons.plus,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _create,
      ),
      children: [
        if (error != null) GlNotice(error!),
        if (loading && items.isEmpty)
          const GlLoading()
        else if (items.isEmpty)
          GlEmpty(
            icon: LucideIcons.flame,
            message: 'Belum ada batch produksi.',
            actionLabel: 'Buat batch hari ini',
            onAction: _create,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Gl.stack),
            child: Row(
              children: [
                Expanded(
                  child: GlStatPill(
                    label: 'Masih draf',
                    value: '$draft batch',
                    tint: Gl.amber,
                    foreground: Gl.amberInk,
                  ),
                ),
                const SizedBox(width: Gl.gap),
                Expanded(
                  child: GlStatPill(label: 'Siap kirim', value: '$ready batch'),
                ),
              ],
            ),
          ),
          for (final day in days) ...[
            GlSectionHead(day.label),
            for (final batch in day.rows)
              _BatchTile(batch: batch, onTap: () => _open(batch['id'] as String)),
            const SizedBox(height: Gl.stack - Gl.gap),
          ],
        ],
      ],
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.batch, required this.onTap});

  final Map<String, dynamic> batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = batch['status'] as String? ?? '';
    final tone = toneForStatus(status);
    final paint = tintForTone(tone);
    final notes = (batch['notes'] as String?)?.trim();

    return GlTile(
      leading: GlGlyph(
        icon: iconForStatus(status),
        tint: paint.tint,
        foreground: paint.ink,
      ),
      title: batch['code'] as String? ?? 'Batch',
      subtitle: notes == null || notes.isEmpty ? statusLabel(status) : notes,
      trailing: StatusChip(statusLabel(status), tone: tone),
      chevron: true,
      onTap: onTap,
    );
  }
}
