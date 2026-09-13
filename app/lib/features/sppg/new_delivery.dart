import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'delivery_page.dart';

/// Satu pilihan dalam daftar yang dibuka dari sebuah baris.
typedef _Choice = ({String id, String label, String? detail});

/// Satu baris muatan yang sedang disusun di layar.
class _Line {
  _Line({required this.component, required int portions})
      : portions = TextEditingController(text: '$portions');

  _Choice component;
  final TextEditingController portions;

  int get value => int.tryParse(portions.text.trim()) ?? 0;

  void dispose() => portions.dispose();
}

class NewDeliveryPage extends StatefulWidget {
  const NewDeliveryPage({super.key});

  @override
  State<NewDeliveryPage> createState() => _NewDeliveryPageState();
}

class _NewDeliveryPageState extends State<NewDeliveryPage> {
  List<_Choice> schools = const [];
  List<_Choice> components = const [];
  String? schoolId;
  final List<_Line> lines = [];
  bool loading = true;
  bool busy = false;

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
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final session = SessionScope.of(context);
    final tenantId = session.current!.id;
    try {
      final links = await session.api.linkedSchools(tenantId);
      final comps = await session.api.readyComponents(tenantId);
      if (!mounted) return;
      setState(() {
        schools = [
          for (final row in links.where((r) => r['status'] == 'active'))
            (
              id: row['school_id'] as String,
              label: (row['schools'] as Map?)?['name'] as String? ?? 'Sekolah',
              detail: (row['schools'] as Map?)?['school_code'] as String?,
            ),
        ];
        components = [
          for (final comp in comps)
            (
              id: comp['id'] as String,
              label: comp['name'] as String? ?? 'Komponen',
              detail: '${(comp['batches'] as Map?)?['code'] ?? ''} · '
                  'tersedia ${comp['portions_produced']} porsi',
            ),
        ];
        schoolId = schools.isEmpty ? null : schools.first.id;
        if (lines.isEmpty && components.isNotEmpty) {
          lines.add(_Line(component: components.first, portions: 50));
        }
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      await showGlError(context, e.message);
    }
  }

  /// Komponen yang belum dipakai baris lain, supaya tidak ada duplikat —
  /// `delivery_items` menolak komponen yang sama dua kali dalam satu kiriman.
  List<_Choice> _available({String? keep}) {
    final used = {for (final line in lines) line.component.id}..remove(keep);
    return components.where((c) => !used.contains(c.id)).toList();
  }

  Future<_Choice?> _pick(String title, List<_Choice> options, String? selected) {
    return Navigator.of(context).push<_Choice>(
      CupertinoPageRoute(
        builder: (_) => _PickerPage(title: title, options: options, selected: selected),
      ),
    );
  }

  Future<void> _pickSchool() async {
    final picked = await _pick('Pilih sekolah', schools, schoolId);
    if (picked != null && mounted) setState(() => schoolId = picked.id);
  }

  Future<void> _pickComponent(_Line line) async {
    final options = _available(keep: line.component.id);
    if (options.isEmpty) return;
    final picked = await _pick('Komponen siap', options, line.component.id);
    if (picked != null && mounted) setState(() => line.component = picked);
  }

  void _addLine() {
    final options = _available();
    if (options.isEmpty) return;
    setState(() => lines.add(_Line(component: options.first, portions: 50)));
  }

  void _removeLine(_Line line) {
    setState(() {
      lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _save() async {
    if (schoolId == null) {
      await showGlError(context, 'Pilih sekolah tujuan lebih dulu.');
      return;
    }
    if (lines.isEmpty) {
      await showGlError(context, 'Tambahkan minimal satu komponen ke kiriman.');
      return;
    }

    setState(() => busy = true);
    final session = SessionScope.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final id = await session.api.createDelivery(
        tenantId: session.current!.id,
        schoolId: schoolId!,
        items: [
          for (final line in lines)
            DeliveryLine(
              componentId: line.component.id,
              portions: line.value,
              label: line.component.label,
            ),
        ],
      );
      if (!mounted) return;
      Navigator.pop(context);
      await navigator.push(
        CupertinoPageRoute(builder: (_) => DeliveryPage(deliveryId: id)),
      );
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  _Choice? get _school {
    for (final option in schools) {
      if (option.id == schoolId) return option;
    }
    return null;
  }

  int get _totalPortions =>
      lines.fold<int>(0, (sum, line) => sum + (line.value < 0 ? 0 : line.value));

  @override
  Widget build(BuildContext context) {
    final ready = schools.isNotEmpty && lines.isNotEmpty;
    final school = _school;
    final canAdd = _available().isNotEmpty;

    return GlDetail(
      title: 'Kiriman baru',
      loading: loading,
      bottomBar: GlButton(
        label: 'Buat draf kiriman',
        onPressed: ready && !busy ? _save : null,
        busy: busy,
      ),
      children: [
        GlSection(
          header: 'Tujuan',
          children: [
            GlRow(
              leading: const GlGlyph(
                icon: CupertinoIcons.building_2_fill,
                tint: Gl.mint,
                foreground: Gl.mintInk,
              ),
              title: school?.label ?? 'Belum ada sekolah aktif',
              subtitle: school?.detail,
              onTap: schools.isEmpty ? null : _pickSchool,
              chevron: schools.isNotEmpty,
            ),
          ],
        ),
        GlSectionHead(
          'Muatan',
          actionLabel: canAdd ? 'Tambah komponen' : null,
          onAction: canAdd ? _addLine : null,
        ),
        if (components.isEmpty)
          const GlEmpty(
            icon: CupertinoIcons.cube_box,
            message: 'Belum ada komponen siap. Finalkan batch produksi lebih dulu.',
          )
        else
          for (final line in lines)
            _LineCard(
              line: line,
              canRemove: lines.length > 1,
              onPick: () => _pickComponent(line),
              onRemove: () => _removeLine(line),
              onChanged: () => setState(() {}),
            ),
        if (lines.isNotEmpty)
          GlSection(
            footer: 'Seluruh komponen di atas berangkat bersama dalam satu kiriman '
                'dan berbagi satu kode QR.',
            children: [
              GlRow(
                title: 'Total porsi',
                value: '$_totalPortions porsi',
                chevron: false,
              ),
            ],
          ),
        if (schools.isEmpty)
          const GlFootnote(
            'Belum ada sekolah aktif. Hubungkan sekolah dari tab Hari ini, lalu minta '
            'sekolah menerima undangan.',
          ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.canRemove,
    required this.onPick,
    required this.onRemove,
    required this.onChanged,
  });

  final _Line line;
  final bool canRemove;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return GlSection(
      children: [
        GlRow(
          leading: const GlGlyph(
            icon: CupertinoIcons.cube_box,
            tint: Gl.amber,
            foreground: Gl.amberInk,
          ),
          title: line.component.label,
          subtitle: line.component.detail,
          onTap: onPick,
        ),
        GlFormRow(
          label: 'Porsi',
          controller: line.portions,
          keyboardType: TextInputType.number,
          placeholder: '0',
          suffix: 'porsi',
          onChanged: (_) => onChanged(),
        ),
        if (canRemove)
          GlActionRow(label: 'Hapus komponen ini', tone: Gl.red, onTap: onRemove),
      ],
    );
  }
}

/// Daftar pilihan dengan tanda centang pada yang sedang dipakai.
class _PickerPage extends StatelessWidget {
  const _PickerPage({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<_Choice> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return GlDetail(
      title: title,
      children: [
        GlSection(
          children: [
            for (final option in options)
              GlRow(
                title: option.label,
                subtitle: option.detail,
                strong: true,
                chevron: false,
                trailing: option.id == selected
                    ? const Icon(CupertinoIcons.checkmark_alt, size: 18, color: Gl.primary)
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ],
    );
  }
}
