import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Kebijakan konsumsi: berapa lama porsi masih dalam batas waktu, dan kapan
/// mulai diperingatkan. Batch tidak bisa dibuat sebelum ini ada, jadi layar ini
/// adalah langkah pertama sebuah SPPG baru.
class PolicyPage extends StatefulWidget {
  const PolicyPage({super.key});

  @override
  State<PolicyPage> createState() => _PolicyPageState();
}

class _PolicyPageState extends State<PolicyPage> {
  final name = TextEditingController();
  final duration = TextEditingController();
  final warning = TextEditingController();
  final note = TextEditingController();

  Map<String, dynamic>? active;
  List<Map<String, dynamic>> history = const [];
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

  @override
  void dispose() {
    name.dispose();
    duration.dispose();
    warning.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final tenantId = session.current!.id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final current = await session.api.activePolicy(tenantId);
      final rows = await session.api.policyHistory(tenantId);
      if (!mounted) return;
      setState(() {
        active = current;
        history = rows;
        loading = false;
        name.text = (current?['name'] as String?) ?? 'Kebijakan konsumsi harian';
        duration.text = '${current?['duration_minutes'] ?? 240}';
        warning.text = '${current?['warning_minutes'] ?? 60}';
        note.text = (current?['source_note'] as String?) ?? '';
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final session = SessionScope.of(context);
    setState(() => busy = true);
    try {
      await session.api.savePolicy(
        tenantId: session.current!.id,
        userId: session.user!.id,
        name: name.text,
        durationMinutes: int.tryParse(duration.text.trim()) ?? 0,
        warningMinutes: int.tryParse(warning.text.trim()) ?? 0,
        sourceNote: note.text,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (active?['duration_minutes'] as num?)?.toInt();

    return GlDetail(
      title: 'Kebijakan konsumsi',
      loading: loading && active == null && history.isEmpty,
      bottomBar: GlButton(
        label: active == null ? 'Terbitkan kebijakan' : 'Terbitkan versi baru',
        onPressed: busy ? null : _save,
        busy: busy,
      ),
      children: [
        if (error != null) GlNotice(error!),
        if (active == null)
          const GlNotice(
            'Belum ada kebijakan aktif. Batch produksi tidak bisa dibuat sampai '
            'kebijakan ini diterbitkan.',
          )
        else
          GlHero(
            caption: 'Batas waktu konsumsi berlaku',
            value: _hours(minutes ?? 0),
            unit: 'sejak matang',
            footer: active?['name'] as String?,
            chips: [
              GlHeroChip(label: 'versi', value: '${active?['version'] ?? 1}'),
              GlHeroChip(
                label: 'menit peringatan',
                value: '${active?['warning_minutes'] ?? 0}',
              ),
            ],
          ),
        const SizedBox(height: Gl.stack),
        GlSection(
          header: 'Aturan',
          footer: 'Durasi dihitung sejak waktu matang dicatat. Peringatan harus lebih '
              'singkat dari durasi — itu batas kapan porsi disebut mendekati batas waktu.',
          children: [
            GlTextRow(controller: name, placeholder: 'Nama kebijakan'),
            GlFormRow(
              label: 'Durasi',
              controller: duration,
              keyboardType: TextInputType.number,
              placeholder: '240',
              suffix: 'menit',
            ),
            GlFormRow(
              label: 'Peringatan',
              controller: warning,
              keyboardType: TextInputType.number,
              placeholder: '60',
              suffix: 'menit',
            ),
          ],
        ),
        GlSection(
          header: 'Dasar penetapan',
          footer: 'Tulis rujukannya — misalnya pedoman dinas kesehatan atau SOP dapur. '
              'Catatan ini ikut tersimpan pada setiap batch sebagai bukti.',
          children: [
            GlTextRow(
              controller: note,
              placeholder: 'Sumber atau alasan penetapan',
            ),
          ],
        ),
        const GlFootnote(
          'Menerbitkan versi baru tidak mengubah batch yang sudah berjalan. Batch '
          'memakai salinan aturan yang berlaku saat batch itu dibuat.',
        ),
        if (history.length > 1) ...[
          const GlSectionHead('Riwayat versi'),
          for (final row in history)
            GlTile(
              leading: GlGlyph(
                icon: LucideIcons.fileText,
                tint: row['retired_at'] == null ? Gl.mint : Gl.fill,
                foreground: row['retired_at'] == null ? Gl.mintInk : Gl.tertiary,
              ),
              title: 'v${row['version']} · ${row['name']}',
              subtitle: '${row['duration_minutes']} menit · peringatan '
                  '${row['warning_minutes']} menit',
              trailing: row['retired_at'] == null
                  ? const StatusChip('Aktif', tone: ChipTone.good)
                  : const StatusChip('Pensiun', tone: ChipTone.neutral),
            ),
        ],
      ],
    );
  }

  static String _hours(int minutes) {
    if (minutes <= 0) return '—';
    if (minutes % 60 == 0) return '${minutes ~/ 60} jam';
    if (minutes < 60) return '$minutes menit';
    return '${(minutes / 60).toStringAsFixed(1)} jam';
  }
}
