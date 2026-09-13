import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Menetralkan sel supaya tidak dieksekusi sebagai rumus saat CSV dibuka di
/// spreadsheet. Aturannya sama persis dengan `neutralizeCsv` di web.
String neutralizeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  if (RegExp(r'^[=+\-@\t\r\n]|^[\x00-\x20]+[=+\-@]').hasMatch(escaped)) return "'$escaped";
  return escaped;
}

String toCsv(List<List<String>> rows) => rows
    .map((row) => row.map((cell) => '"${neutralizeCsv(cell)}"').join(','))
    .join('\n');

/// Laporan CSV dibuat di dalam app lalu dibagikan lewat share sheet, jadi
/// tidak ada endpoint web yang perlu dipanggil.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool busyOperations = false;
  bool busyFinance = false;
  String? error;

  String get _stamp => DateFormat('yyyyMMdd-HHmm').format(DateTime.now());

  Future<void> _shareCsv(String filename, String csv, String title) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      mimeType: 'text/csv',
      name: filename,
    );
    await Share.shareXFiles(
      [file],
      subject: title,
      fileNameOverrides: [filename],
    );
  }

  Future<void> _operations() async {
    final session = SessionScope.of(context);
    final tenantId = session.current!.id;
    setState(() {
      busyOperations = true;
      error = null;
    });
    try {
      final deliveries = await session.api.deliveries(tenantId: tenantId);
      final rows = <List<String>>[
        ['kode', 'sekolah', 'status', 'dibuat', 'dikirim'],
        for (final d in deliveries)
          [
            d['code'] as String? ?? '',
            (d['schools'] as Map?)?['name'] as String? ?? '',
            statusLabel(d['status'] as String? ?? ''),
            _iso(d['created_at']),
            _iso(d['dispatched_at']),
          ],
      ];
      await _shareCsv(
        'gizilacak-kiriman-$_stamp.csv',
        toCsv(rows),
        'Laporan kiriman',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busyOperations = false);
    }
  }

  Future<void> _finance() async {
    final session = SessionScope.of(context);
    final tenantId = session.current!.id;
    setState(() {
      busyFinance = true;
      error = null;
    });
    try {
      final expenses = await session.api.expenses(tenantId);
      final invoices = await session.api.invoices(tenantId);
      final rows = <List<String>>[
        ['jenis', 'keterangan', 'kategori', 'status', 'tanggal', 'nominal_rp'],
        for (final e in expenses)
          [
            'biaya',
            e['description'] as String? ?? '',
            e['category'] as String? ?? '',
            e['status'] as String? ?? '',
            e['expense_date'] as String? ?? '',
            '${e['amount_rp'] ?? 0}',
          ],
        for (final i in invoices)
          [
            'tagihan',
            i['number'] as String? ?? '',
            '',
            i['status'] as String? ?? '',
            _iso(i['issued_at']),
            '${i['total_rp'] ?? 0}',
          ],
      ];
      await _shareCsv(
        'gizilacak-keuangan-$_stamp.csv',
        toCsv(rows),
        'Laporan keuangan',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busyFinance = false);
    }
  }

  static String _iso(Object? raw) {
    final when = parseDate(raw)?.toLocal();
    return when == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(when);
  }

  @override
  Widget build(BuildContext context) {
    return GlDetail(
      title: 'Laporan',
      children: [
        if (error != null) GlNotice(error!),
        GlSection(
          header: 'Unduh CSV',
          footer: 'Berkas dibuat di dalam aplikasi lalu dibagikan lewat menu berbagi '
              'HP — bisa disimpan, dikirim ke WhatsApp, atau dilampirkan ke email.',
          children: [
            GlRow(
              leading: const GlGlyph(
                icon: LucideIcons.package,
                tint: Gl.lilac,
                foreground: Gl.primary,
              ),
              title: 'Kiriman',
              subtitle: 'Kode, sekolah, status, waktu kirim',
              trailing: busyOperations ? const GlSpinner() : null,
              onTap: busyOperations ? null : _operations,
              chevron: !busyOperations,
            ),
            GlRow(
              leading: const GlGlyph(
                icon: LucideIcons.circleDollarSign,
                tint: Gl.mint,
                foreground: Gl.mintInk,
              ),
              title: 'Keuangan',
              subtitle: 'Biaya operasional dan tagihan',
              trailing: busyFinance ? const GlSpinner() : null,
              onTap: busyFinance ? null : _finance,
              chevron: !busyFinance,
            ),
          ],
        ),
        const GlFootnote(
          'Sel yang diawali =, +, -, atau @ diberi tanda kutip supaya tidak dijalankan '
          'sebagai rumus saat berkas dibuka di spreadsheet.',
        ),
      ],
    );
  }
}
