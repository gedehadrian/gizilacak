import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Insiden kiriman. Sekolah melaporkan, SPPG menindaklanjuti — sesuai RLS:
/// anggota sekolah boleh membuat, hanya owner/manager SPPG boleh menutup.
class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  static const categories = {
    'quality': 'Kualitas makanan',
    'late': 'Keterlambatan',
    'missing_information': 'Informasi kurang',
    'other': 'Lainnya',
  };
  static const severities = {'low': 'Ringan', 'medium': 'Sedang', 'high': 'Berat'};

  List<Map<String, dynamic>> items = const [];
  List<Map<String, dynamic>> deliveries = const [];
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
    final org = session.current!;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = await session.api.incidents(
        tenantId: org.isTenant ? org.id : null,
        schoolId: org.isTenant ? null : org.id,
      );
      final dels = await session.api.deliveries(
        tenantId: org.isTenant ? org.id : null,
        schoolId: org.isTenant ? null : org.id,
      );
      if (!mounted) return;
      setState(() {
        items = rows;
        deliveries = dels;
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

  Future<void> _report() async {
    if (deliveries.isEmpty) {
      await showGlError(context, 'Insiden harus menunjuk satu kiriman. Belum ada kiriman.');
      return;
    }

    final delivery = await showGlSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => GlSheet(
        title: const Text('Kiriman mana?'),
        actions: [
          for (final d in deliveries.take(12))
            GlSheetAction(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(d['code'] as String? ?? 'Kiriman'),
            ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
    if (delivery == null || !mounted) return;

    final description = TextEditingController();
    var category = categories.keys.first;
    var severity = 'medium';

    final confirmed = await showGlDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => GlDialog(
          title: Text('Laporkan ${delivery['code']}'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              GlInput(
                controller: description,
                placeholder: 'Apa yang terjadi',
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              GlSegments<String>(
                groupValue: severity,
                children: {
                  for (final entry in severities.entries)
                    entry.key: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: Text(entry.value, style: const TextStyle(fontSize: 12)),
                    ),
                },
                onValueChanged: (v) => setDialog(() => severity = v ?? severity),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: GlChoicePicker(
                  itemExtent: 26,
                  onSelectedItemChanged: (i) =>
                      setDialog(() => category = categories.keys.elementAt(i)),
                  children: [
                    for (final label in categories.values)
                      Center(child: Text(label, style: const TextStyle(fontSize: 13))),
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
              child: const Text('Laporkan'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = SessionScope.of(context);
    final org = session.current!;
    try {
      await session.api.createIncident(
        tenantId: delivery['tenant_id'] as String,
        schoolId: org.isTenant ? delivery['school_id'] as String : org.id,
        deliveryId: delivery['id'] as String,
        userId: session.user!.id,
        category: category,
        severity: severity,
        description: description.text,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _resolve(Map<String, dynamic> incident) async {
    final session = SessionScope.of(context);
    final org = session.current!;
    if (!org.isTenant) return;

    final resolution = TextEditingController(
      text: incident['resolution'] as String? ?? '',
    );
    final picked = await showGlDialog<String>(
      context: context,
      builder: (ctx) => GlDialog(
        title: const Text('Tindak lanjut'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GlInput(
            controller: resolution,
            placeholder: 'Apa yang dilakukan',
            maxLines: 3,
          ),
        ),
        actions: [
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, 'in_review'),
            child: const Text('Sedang ditinjau'),
          ),
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, 'resolved'),
            child: const Text('Selesai'),
          ),
          GlDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    try {
      await session.api.setIncidentStatus(
        tenantId: org.id,
        id: incident['id'] as String,
        status: picked,
        resolution: resolution.text,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = SessionScope.of(context).current!;
    final open = items.where((i) => i['status'] == 'open' || i['status'] == 'in_review').toList();
    final done = items.where((i) => i['status'] == 'resolved' || i['status'] == 'closed').toList();

    return GlDetail(
      title: 'Insiden',
      loading: loading && items.isEmpty,
      trailing: GlCircleButton(
        icon: LucideIcons.plus,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _report,
      ),
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Insiden belum selesai',
          value: '${open.length}',
          unit: open.length == 1 ? 'laporan' : 'laporan',
          footer: org.isTenant
              ? 'Ketuk satu laporan untuk menindaklanjuti.'
              : 'SPPG akan menindaklanjuti laporan Anda.',
          chips: [
            if (done.isNotEmpty) GlHeroChip(label: 'selesai', value: '${done.length}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        if (items.isEmpty && !loading)
          GlEmpty(
            icon: LucideIcons.messageSquareWarning,
            message: 'Belum ada insiden. Laporkan kalau ada kiriman yang bermasalah.',
            actionLabel: 'Laporkan insiden',
            onAction: _report,
          ),
        if (open.isNotEmpty) ...[
          const GlSectionHead('Perlu tindak lanjut'),
          for (final incident in open) _tile(incident, org.isTenant),
          const SizedBox(height: Gl.stack - Gl.gap),
        ],
        if (done.isNotEmpty) ...[
          const GlSectionHead('Sudah selesai'),
          for (final incident in done) _tile(incident, false),
        ],
      ],
    );
  }

  Widget _tile(Map<String, dynamic> incident, bool canResolve) {
    final severity = incident['severity'] as String? ?? 'low';
    final tone = switch (severity) {
      'high' => ChipTone.bad,
      'medium' => ChipTone.warn,
      _ => ChipTone.neutral,
    };
    final paint = tintForTone(tone);
    final code = (incident['deliveries'] as Map?)?['code'] as String?;

    return GlTile(
      leading: GlGlyph(
        icon: LucideIcons.messageSquareWarning,
        tint: paint.tint,
        foreground: paint.ink,
      ),
      title: categories[incident['category']] ?? 'Insiden',
      subtitle: [
        ?code,
        incident['description'] as String? ?? '',
      ].join(' · '),
      trailing: StatusChip(severities[severity] ?? severity, tone: tone),
      chevron: canResolve,
      onTap: canResolve ? () => _resolve(incident) : null,
    );
  }
}
