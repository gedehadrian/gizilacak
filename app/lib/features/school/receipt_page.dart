import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  Map<String, dynamic>? delivery;
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await SessionScope.of(context).api.delivery(widget.deliveryId);
      if (mounted) {
        setState(() {
          delivery = data;
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

  Map<String, Map<String, dynamic>> get receipts {
    final rows =
        List<Map<String, dynamic>>.from((delivery?['receipts'] as List?) ?? const []);
    return {for (final row in rows) row['delivery_item_id'] as String: row};
  }

  @override
  Widget build(BuildContext context) {
    final items =
        List<Map<String, dynamic>>.from((delivery?['delivery_items'] as List?) ?? const []);
    final status = delivery?['status'] as String? ?? '';
    final dispatchedAt = parseDate(delivery?['dispatched_at'])?.toLocal();
    final done = receipts;
    final portions = items.fold<int>(
      0,
      (sum, item) => sum + ((item['portions'] as num?)?.toInt() ?? 0),
    );

    return GlDetail(
      title: delivery?['code'] as String? ?? 'Penerimaan',
      subtitle: dispatchedAt == null ? null : 'Dikirim ${dateTimeLabel(dispatchedAt)}',
      loading: loading && delivery == null,
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Porsi yang dikirim',
          value: '$portions',
          unit: 'porsi',
          footer: 'Isi jumlah diterima dan ditolak di bawah ini.',
          chips: [
            GlHeroChip(label: statusLabel(status)),
            GlHeroChip(label: 'sudah dicatat', value: '${done.length}/${items.length}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        const GlFootnote(
          'Scan siswa tidak mengubah catatan penerimaan. Jumlah di bawah ini yang dipakai '
          'sebagai catatan resmi sekolah.',
        ),
        for (final item in items)
          _ItemSection(
            item: item,
            receipt: done[item['id'] as String],
            canSubmit: status == 'dispatched',
            onDone: _load,
          ),
      ],
    );
  }
}

class _ItemSection extends StatefulWidget {
  const _ItemSection({
    required this.item,
    required this.receipt,
    required this.canSubmit,
    required this.onDone,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic>? receipt;
  final bool canSubmit;
  final Future<void> Function() onDone;

  @override
  State<_ItemSection> createState() => _ItemSectionState();
}

class _ItemSectionState extends State<_ItemSection> {
  late final accepted = TextEditingController(text: '${widget.item['portions']}');
  late final rejected = TextEditingController(text: '0');
  final reason = TextEditingController();
  final note = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    accepted.dispose();
    rejected.dispose();
    reason.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = int.tryParse(accepted.text.trim()) ?? -1;
    final r = int.tryParse(rejected.text.trim()) ?? -1;
    if (a < 0 || r < 0) {
      await showGlError(context, 'Isi jumlah diterima dan ditolak dengan angka.');
      return;
    }
    setState(() => busy = true);
    try {
      await SessionScope.of(context).api.submitReceipt(
            deliveryItemId: widget.item['id'] as String,
            accepted: a,
            rejected: r,
            reason: reason.text.trim(),
            note: note.text.trim(),
          );
      await widget.onDone();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.item['batch_components'] as Map?)?['name'] as String? ?? 'Komponen';
    final sent = widget.item['portions'];
    final receipt = widget.receipt;

    if (receipt != null) {
      return GlSection(
        header: name,
        children: [
          GlRow(
            leading: const GlGlyph(icon: CupertinoIcons.cube_box),
            title: 'Dikirim',
            value: '$sent porsi',
            chevron: false,
          ),
          GlRow(
            leading: const GlGlyph(
              icon: CupertinoIcons.checkmark_alt,
              tint: Gl.mint,
              foreground: Gl.mintInk,
            ),
            title: 'Diterima',
            value: '${receipt['accepted_portions'] ?? 0} porsi',
            valueColor: Gl.mintInk,
            chevron: false,
          ),
          GlRow(
            leading: const GlGlyph(
              icon: CupertinoIcons.xmark,
              tint: Gl.blush,
              foreground: Gl.blushInk,
            ),
            title: 'Ditolak',
            value: '${receipt['rejected_portions'] ?? 0} porsi',
            valueColor: Gl.blushInk,
            chevron: false,
          ),
          const GlChipRow(chip: StatusChip('Sudah dicatat', tone: ChipTone.good)),
        ],
      );
    }

    if (!widget.canSubmit) {
      return GlSection(
        header: name,
        footer: 'Penerimaan bisa dicatat setelah SPPG menandai kiriman ini berangkat.',
        children: [
          GlRow(
            leading: const GlGlyph(icon: CupertinoIcons.cube_box),
            title: 'Dikirim',
            value: '$sent porsi',
            chevron: false,
          ),
        ],
      );
    }

    return GlSection(
      header: name,
      footer: 'Alasan dan catatan hanya perlu diisi kalau ada porsi yang ditolak.',
      children: [
        GlRow(
          leading: const GlGlyph(icon: CupertinoIcons.cube_box),
          title: 'Dikirim',
          value: '$sent porsi',
          chevron: false,
        ),
        GlFormRow(
          label: 'Diterima',
          controller: accepted,
          keyboardType: TextInputType.number,
          placeholder: '0',
          suffix: 'porsi',
        ),
        GlFormRow(
          label: 'Ditolak',
          controller: rejected,
          keyboardType: TextInputType.number,
          placeholder: '0',
          suffix: 'porsi',
        ),
        GlTextRow(controller: reason, placeholder: 'Alasan penolakan'),
        GlTextRow(controller: note, placeholder: 'Catatan kondisi makanan'),
        GlActionRow(
          label: 'Simpan penerimaan',
          onTap: busy ? null : _save,
          busy: busy,
        ),
      ],
    );
  }
}
