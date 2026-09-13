import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'receipt_page.dart';

class SchoolTodayTab extends StatefulWidget {
  const SchoolTodayTab({super.key});

  @override
  State<SchoolTodayTab> createState() => _SchoolTodayTabState();
}

class _SchoolTodayTabState extends State<SchoolTodayTab> {
  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> pending = const [];
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
    final schoolId = session.current!.id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dels = await session.api.deliveries(schoolId: schoolId);
      final links = await session.api.pendingSchoolLinks(schoolId);
      if (mounted) {
        setState(() {
          items = dels;
          pending = links;
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

  Future<void> _accept(String linkId, String sppg) async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text('Terima $sppg'),
        message: const Text(
          'Setelah diterima, SPPG ini bisa mengirim makanan ke sekolah Anda.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terima'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.of(context).api.acceptSchoolLink(linkId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _open(String deliveryId) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => ReceiptPage(deliveryId: deliveryId)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final org = SessionScope.of(context).current!;
    final days = groupByDay(items, 'created_at', toLocal: true);
    final waiting = items.where((d) => d['status'] == 'dispatched').length;
    final settled = items.where((d) => d['status'] == 'completed').length;

    return GlSliver(
      title: org.name,
      subtitle: org.code.isEmpty ? 'Sekolah' : 'Sekolah · ${org.code}',
      badge: monogram(org.name),
      onRefresh: _load,
      children: [
        if (error != null) GlNotice(error!),
        if (loading && items.isEmpty && pending.isEmpty)
          const GlLoading()
        else ...[
          GlHero(
            caption: 'Menunggu dicatat penerimaannya',
            value: '$waiting',
            unit: waiting == 1 ? 'kiriman' : 'kiriman',
            footer: 'Scan siswa tidak mengubah catatan ini.',
            chips: [
              GlHeroChip(label: 'selesai', value: '$settled'),
              if (pending.isNotEmpty)
                GlHeroChip(label: 'undangan SPPG', value: '${pending.length}'),
            ],
          ),
          const SizedBox(height: Gl.stack),
          if (pending.isNotEmpty) ...[
            const GlSectionHead('Undangan SPPG'),
            for (final row in pending)
              GlTile(
                leading: const GlGlyph(
                  icon: CupertinoIcons.envelope,
                  tint: Gl.amber,
                  foreground: Gl.amberInk,
                ),
                title: (row['tenants'] as Map?)?['name'] as String? ?? 'SPPG',
                subtitle: 'Ketuk untuk menerima',
                trailing: const StatusChip('Menunggu', tone: ChipTone.warn),
                chevron: true,
                onTap: () => _accept(
                  row['id'] as String,
                  (row['tenants'] as Map?)?['name'] as String? ?? 'SPPG',
                ),
              ),
            const SizedBox(height: Gl.stack - Gl.gap),
          ],
          if (items.isEmpty)
            const GlEmpty(
              icon: CupertinoIcons.tray,
              message: 'Belum ada kiriman masuk. Siswa memindai QR di browser, bukan di '
                  'aplikasi ini.',
            )
          else
            for (final day in days) ...[
              GlSectionHead(day.label),
              for (final delivery in day.rows)
                _IncomingTile(
                  delivery: delivery,
                  onTap: () => _open(delivery['id'] as String),
                ),
              const SizedBox(height: Gl.stack - Gl.gap),
            ],
        ],
      ],
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({required this.delivery, required this.onTap});

  final Map<String, dynamic> delivery;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = delivery['status'] as String? ?? '';
    final tone = toneForStatus(status);
    final paint = tintForTone(tone);

    return GlTile(
      leading: GlGlyph(
        icon: iconForStatus(status),
        tint: paint.tint,
        foreground: paint.ink,
      ),
      title: delivery['code'] as String? ?? 'Kiriman',
      subtitle: status == 'dispatched' ? 'Catat penerimaan porsi' : statusLabel(status),
      trailing: StatusChip(statusLabel(status), tone: tone),
      chevron: true,
      onTap: onTap,
    );
  }
}
