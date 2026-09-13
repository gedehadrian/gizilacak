import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config.dart';
import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  Map<String, dynamic>? delivery;
  bool loading = true;
  bool busy = false;
  String? error;
  bool copied = false;

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

  String? get token {
    final labels =
        List<Map<String, dynamic>>.from((delivery?['qr_labels'] as List?) ?? const []);
    final live = labels.where((q) => q['revoked_at'] == null);
    return live.isEmpty ? null : live.first['token'] as String?;
  }

  Map<String, Map<String, dynamic>> get receipts {
    final rows =
        List<Map<String, dynamic>>.from((delivery?['receipts'] as List?) ?? const []);
    return {for (final row in rows) row['delivery_item_id'] as String: row};
  }

  Future<void> _dispatch() async {
    setState(() => busy = true);
    try {
      await SessionScope.of(context).api.dispatch(widget.deliveryId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) setState(() => copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final status = delivery?['status'] as String? ?? '';
    final school = (delivery?['schools'] as Map?)?['name'] as String? ?? 'Sekolah';
    final items =
        List<Map<String, dynamic>>.from((delivery?['delivery_items'] as List?) ?? const []);
    final createdAt = parseDate(delivery?['created_at'])?.toLocal();
    final dispatchedAt = parseDate(delivery?['dispatched_at'])?.toLocal();
    final qrUrl = token == null ? null : '${AppConfig.webAppUrl}/scan/$token';
    final done = receipts;
    final portions = items.fold<int>(
      0,
      (sum, item) => sum + ((item['portions'] as num?)?.toInt() ?? 0),
    );

    return GlDetail(
      title: delivery?['code'] as String? ?? 'Kiriman',
      subtitle: school,
      loading: loading && delivery == null,
      bottomBar: status == 'draft'
          ? GlButton(
              label: 'Kirim sekarang',
              onPressed: busy ? null : _dispatch,
              busy: busy,
            )
          : null,
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Porsi dalam kiriman ini',
          value: '$portions',
          unit: 'porsi',
          footer: 'Tujuan: $school',
          chips: [
            GlHeroChip(label: statusLabel(status)),
            GlHeroChip(label: 'komponen', value: '${items.length}'),
            if (dispatchedAt != null)
              GlHeroChip(label: 'dikirim ${dateTimeLabel(dispatchedAt)}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        GlSection(
          header: 'Isi kiriman',
          children: [
            for (final item in items)
              GlRow(
                leading: const GlGlyph(icon: LucideIcons.package),
                title: (item['batch_components'] as Map?)?['name'] as String? ?? 'Komponen',
                subtitle: _receiptLine(done[item['id'] as String]),
                value: '${item['portions']} porsi',
                chevron: false,
              ),
          ],
        ),
        GlSection(
          header: 'Rincian',
          children: [
            GlRow(
              title: 'Status',
              chevron: false,
              trailing: StatusChip(statusLabel(status), tone: toneForStatus(status)),
            ),
            if (createdAt != null)
              GlRow(title: 'Dibuat', value: dateTimeLabel(createdAt), chevron: false),
            if (dispatchedAt != null)
              GlRow(title: 'Dikirim', value: dateTimeLabel(dispatchedAt), chevron: false),
          ],
        ),
        if (status == 'draft')
          const GlFootnote(
            'Dispatch membutuhkan langganan aktif. Satu QR dipakai untuk seluruh dus yang '
            'berangkat ke sekolah ini.',
          ),
        if (qrUrl != null) ...[
          const GlSectionHead('Label QR'),
          GlCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                GlQrFrame(
                  size: 200,
                  child: QrImageView(
                    data: qrUrl,
                    padding: EdgeInsets.zero,
                    backgroundColor: Gl.surface,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Gl.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Gl.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  delivery?['code'] as String? ?? '',
                  style: Gl.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Siswa memindai ini dengan kamera HP dan membukanya di browser. '
                  'Tempel di setiap dus — cetak ulang boleh.',
                  style: Gl.footnote,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlButton(
                  label: copied ? 'Tautan tersalin' : 'Salin tautan',
                  filled: false,
                  onPressed: () => _copy(qrUrl),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String? _receiptLine(Map<String, dynamic>? receipt) {
    if (receipt == null) return null;
    final accepted = receipt['accepted_portions'] ?? 0;
    final rejected = receipt['rejected_portions'] ?? 0;
    return 'Sekolah mencatat $accepted diterima · $rejected ditolak';
  }
}
