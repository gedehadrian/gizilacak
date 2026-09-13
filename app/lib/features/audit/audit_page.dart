import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Jejak audit. Hanya owner dan manager yang boleh membacanya (`aud_sel`).
class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  static const labels = {
    'batch.finalize': 'Batch difinalkan',
    'delivery.dispatch': 'Kiriman dikirim',
    'receipt.submit': 'Penerimaan dicatat',
    'invoice.paid': 'Tagihan lunas',
  };

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
      final rows = await session.api.auditLogs(session.current!.id);
      if (mounted) {
        setState(() {
          items = rows;
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
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = SessionScope.of(context).user?.id;
    final days = groupByDay(items, 'occurred_at', toLocal: true);

    return GlDetail(
      title: 'Jejak audit',
      loading: loading && items.isEmpty,
      children: [
        if (error != null) GlNotice(error!),
        if (items.isEmpty && !loading)
          const GlEmpty(
            icon: CupertinoIcons.doc_text_search,
            message: 'Belum ada catatan. Tindakan penting seperti finalkan batch dan '
                'dispatch kiriman tercatat di sini secara otomatis.',
          )
        else
          for (final day in days) ...[
            GlSectionHead(day.label),
            GlSection(
              children: [
                for (final row in day.rows)
                  GlRow(
                    leading: GlGlyph(
                      icon: _icon(row['action'] as String? ?? ''),
                      tint: Gl.fill,
                      foreground: Gl.secondary,
                    ),
                    title: labels[row['action']] ?? row['action'] as String? ?? '—',
                    subtitle: row['actor_id'] == me ? 'oleh Anda' : row['entity_type'] as String?,
                    value: _time(row['occurred_at']),
                    chevron: false,
                  ),
              ],
            ),
          ],
        const GlFootnote(
          'Catatan audit tidak bisa diubah atau dihapus dari aplikasi. Nama pelaku '
          'selain Anda tidak ditampilkan karena aturan privasi di database.',
        ),
      ],
    );
  }

  static String? _time(Object? raw) {
    final when = parseDate(raw)?.toLocal();
    return when == null ? null : timeLabel(when);
  }

  static IconData _icon(String action) {
    if (action.startsWith('batch')) return CupertinoIcons.flame;
    if (action.startsWith('delivery')) return CupertinoIcons.paperplane;
    if (action.startsWith('receipt')) return CupertinoIcons.tray_arrow_down;
    if (action.startsWith('invoice') || action.startsWith('payment')) {
      return CupertinoIcons.creditcard;
    }
    return CupertinoIcons.circle;
  }
}
