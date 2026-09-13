import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class BatchPage extends StatefulWidget {
  const BatchPage({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  Map<String, dynamic>? batch;
  bool loading = true;
  bool busy = false;
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
      final data = await session.api.batch(session.current!.id, widget.batchId);
      if (mounted) {
        setState(() {
          batch = data;
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

  List<Map<String, dynamic>> get comps =>
      List<Map<String, dynamic>>.from((batch?['batch_components'] as List?) ?? const []);

  Future<void> _cook(String componentId) async {
    final session = SessionScope.of(context);
    setState(() => busy = true);
    try {
      await session.api.markCooked(
        tenantId: session.current!.id,
        componentId: componentId,
        cookedAt: DateTime.now(),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _finalize() async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Finalkan batch'),
        message: const Text(
          'Setelah final, waktu matang tidak bisa diubah dan batch bisa dialokasikan '
          'ke kiriman sekolah.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalkan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busy = true);
    try {
      await SessionScope.of(context).api.finalizeBatch(widget.batchId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = batch?['status'] as String? ?? '';
    final draft = status == 'draft';
    final productionDate = parseDate(batch?['production_date']);
    final notes = (batch?['notes'] as String?)?.trim();
    final portions = comps.fold<int>(
      0,
      (sum, c) => sum + ((c['portions_produced'] as num?)?.toInt() ?? 0),
    );
    final cooked = comps.where((c) => c['cooked_at'] != null).length;

    return GlDetail(
      title: batch?['code'] as String? ?? 'Batch',
      subtitle: productionDate == null ? null : dateLabel(productionDate),
      loading: loading && batch == null,
      bottomBar: draft
          ? GlButton(
              label: 'Finalkan batch',
              onPressed: busy ? null : _finalize,
              busy: busy,
            )
          : null,
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Porsi diproduksi',
          value: '$portions',
          unit: 'porsi',
          footer: notes == null || notes.isEmpty ? null : notes,
          chips: [
            GlHeroChip(label: statusLabel(status)),
            GlHeroChip(label: 'komponen matang', value: '$cooked/${comps.length}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        if (draft)
          const GlFootnote(
            'Catat waktu matang aktual. Batas waktu konsumsi dihitung dari waktu itu, '
            'memakai kebijakan yang berlaku saat batch dibuat.',
          ),
        for (final comp in comps)
          _ComponentSection(
            component: comp,
            draft: draft,
            busy: busy,
            onCook: () => _cook(comp['id'] as String),
          ),
        if (status == 'ready')
          const GlFootnote('Batch sudah final. Alokasikan porsinya dari tab Kiriman.'),
      ],
    );
  }
}

class _ComponentSection extends StatelessWidget {
  const _ComponentSection({
    required this.component,
    required this.draft,
    required this.busy,
    required this.onCook,
  });

  final Map<String, dynamic> component;
  final bool draft;
  final bool busy;
  final VoidCallback onCook;

  @override
  Widget build(BuildContext context) {
    final cookedAt = parseDate(component['cooked_at'])?.toLocal();
    final consumeBy = parseDate(component['consume_by'])?.toLocal();
    final warning = (component['warning_minutes_snapshot'] as num?)?.toInt() ?? 60;
    final window = consumptionWindow(consumeBy, warningMinutes: warning);

    return GlSection(
      header: component['name'] as String? ?? 'Komponen',
      children: [
        GlRow(
          leading: const GlGlyph(icon: CupertinoIcons.chart_pie),
          title: 'Porsi diproduksi',
          value: '${component['portions_produced'] ?? 0}',
          chevron: false,
        ),
        GlRow(
          leading: GlGlyph(
            icon: CupertinoIcons.flame,
            tint: cookedAt == null ? Gl.fill : Gl.amber,
            foreground: cookedAt == null ? Gl.tertiary : Gl.amberInk,
          ),
          title: 'Waktu matang',
          value: cookedAt == null ? 'Belum dicatat' : dateTimeLabel(cookedAt),
          valueColor: cookedAt == null ? Gl.tertiary : null,
          chevron: false,
        ),
        if (consumeBy != null)
          GlRow(
            leading: const GlGlyph(icon: CupertinoIcons.clock),
            title: 'Batas konsumsi',
            value: dateTimeLabel(consumeBy),
            chevron: false,
          ),
        GlChipRow(chip: StatusChip(window.text, tone: window.tone)),
        if (draft && cookedAt == null)
          GlActionRow(
            label: 'Tandai matang sekarang',
            onTap: busy ? null : onCook,
            busy: busy,
          ),
      ],
    );
  }
}
