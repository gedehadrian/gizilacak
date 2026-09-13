import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'payment_webview.dart';
import 'plan_picker_page.dart';

String rupiah(Object? value) {
  final amount = (value as num?)?.toDouble() ?? 0;
  return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
}

/// Langganan dan tagihan. Tanpa langganan aktif, dispatch kiriman ditolak
/// database dengan `no_entitlement`, jadi layar ini bukan pelengkap.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  Map<String, dynamic>? subscription;
  List<Map<String, dynamic>> invoices = const [];
  List<Map<String, dynamic>> usage = const [];
  bool loading = true;
  String? error;
  String? busyInvoiceId;

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
    final tenantId = session.current!.id;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final sub = await session.api.latestSubscription(tenantId);
      final bills = await session.api.invoices(tenantId);
      final counters = await session.api.usage(tenantId);
      if (!mounted) return;
      setState(() {
        subscription = sub;
        invoices = bills;
        usage = counters;
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

  /// Hanya owner dan finance yang boleh menerbitkan tagihan — aturan itu
  /// ditegakkan RPC, dan disebut di sini supaya pesannya jelas lebih awal.
  bool get _canBuy {
    final role = SessionScope.of(context).current?.role;
    return role == 'owner' || role == 'finance';
  }

  Future<void> _openPlans() async {
    if (!_canBuy) {
      await showGlError(
        context,
        'Hanya owner dan penanggung jawab keuangan yang bisa berlangganan.',
      );
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => PlanPickerPage(renewal: subscription != null),
      ),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _pay(Map<String, dynamic> invoice) async {
    final session = SessionScope.of(context);
    setState(() => busyInvoiceId = invoice['id'] as String);
    try {
      final url = await session.api.startCheckout(
        tenantId: session.current!.id,
        invoiceId: invoice['id'] as String,
      );
      if (!mounted) return;
      await openPayment(context, url);
      if (mounted) await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busyInvoiceId = null);
    }
  }

  bool get entitled {
    final sub = subscription;
    if (sub == null || sub['status'] != 'active') return false;
    final end = parseDate(sub['period_end']);
    return end != null && end.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final end = parseDate(subscription?['period_end'])?.toLocal();
    final daysLeft = end?.difference(DateTime.now()).inDays;
    final deliveries = usage.where((u) => u['metric'] == 'deliveries').toList();
    final counter = deliveries.isEmpty ? null : deliveries.first;
    final unpaid = invoices.where((i) => i['status'] != 'paid').toList();

    return GlDetail(
      title: 'Langganan',
      loading: loading && invoices.isEmpty && subscription == null,
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: entitled ? 'Langganan aktif sampai' : 'Status langganan',
          value: entitled && end != null ? DateFormat('d MMM', 'id').format(end) : 'Belum aktif',
          unit: entitled && end != null ? DateFormat('yyyy', 'id').format(end) : null,
          footer: entitled
              ? 'Kiriman bisa didispatch selama periode ini berjalan.'
              : 'Dispatch kiriman diblokir sampai ada langganan aktif.',
          chips: [
            if (daysLeft != null && daysLeft >= 0)
              GlHeroChip(label: 'hari tersisa', value: '$daysLeft'),
            if (counter != null)
              GlHeroChip(
                label: 'kiriman terpakai',
                value: '${counter['used']}/${counter['limit_snapshot']}',
              ),
          ],
        ),
        const SizedBox(height: Gl.stack),
        GlSection(
          header: 'Paket',
          footer: entitled
              ? 'Perpanjangan bisa diterbitkan kapan saja; masa berlakunya '
                  'disambung setelah periode berjalan selesai.'
              : 'Pilih paket untuk menerbitkan tagihan, lalu bayar lewat Midtrans.',
          children: [
            GlRow(
              leading: const GlGlyph(
                icon: LucideIcons.clipboardList,
                tint: Gl.lilac,
                foreground: Gl.primary,
              ),
              title: entitled ? 'Perpanjang paket' : 'Pilih paket',
              subtitle: entitled ? null : 'Belum berlangganan',
              onTap: _openPlans,
            ),
          ],
        ),
        if (counter != null)
          GlSection(
            header: 'Kuota periode ini',
            footer: 'Kalau kuota habis, dispatch ditolak dengan pesan "Kuota kiriman '
                'periode ini habis".',
            children: [
              GlRow(
                leading: const GlGlyph(icon: LucideIcons.package),
                title: 'Kiriman terpakai',
                value: '${counter['used']} dari ${counter['limit_snapshot']}',
                chevron: false,
              ),
            ],
          ),
        if (unpaid.isNotEmpty) ...[
          const GlSectionHead('Belum dibayar'),
          for (final invoice in unpaid)
            _InvoiceTile(
              invoice: invoice,
              busy: busyInvoiceId == invoice['id'],
              onPay: () => _pay(invoice),
            ),
          const SizedBox(height: Gl.stack - Gl.gap),
        ],
        if (invoices.isEmpty)
          GlEmpty(
            icon: LucideIcons.fileText,
            message: 'Belum ada tagihan. Pilih paket untuk menerbitkan tagihan '
                'pertama.',
            actionLabel: 'Pilih paket',
            onAction: _openPlans,
          )
        else ...[
          const GlSectionHead('Semua tagihan'),
          for (final invoice in invoices)
            GlTile(
              leading: GlGlyph(
                icon: LucideIcons.fileText,
                tint: tintForTone(toneForStatus(invoice['status'] as String? ?? '')).tint,
                foreground: tintForTone(toneForStatus(invoice['status'] as String? ?? '')).ink,
              ),
              title: invoice['number'] as String? ?? 'Tagihan',
              subtitle: _period(invoice),
              value: rupiah(invoice['total_rp']),
              trailing: StatusChip(
                _invoiceLabel(invoice['status'] as String? ?? ''),
                tone: toneForStatus(invoice['status'] as String? ?? ''),
              ),
            ),
        ],
        const GlFootnote(
          'Pembayaran diproses Midtrans. Status tagihan diperbarui oleh server setelah '
          'Midtrans mengonfirmasi — bukan oleh aplikasi ini.',
        ),
      ],
    );
  }

  static String? _period(Map<String, dynamic> invoice) {
    final start = parseDate(invoice['service_start']);
    final end = parseDate(invoice['service_end']);
    if (start == null || end == null) return null;
    final f = DateFormat('d MMM', 'id');
    return '${f.format(start)} – ${f.format(end)}';
  }

  static String _invoiceLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Lunas';
      case 'open':
        return 'Belum dibayar';
      case 'draft':
        return 'Draf';
      case 'void':
        return 'Dibatalkan';
      default:
        return statusLabel(status);
    }
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.busy,
    required this.onPay,
  });

  final Map<String, dynamic> invoice;
  final bool busy;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final due = parseDate(invoice['due_at'])?.toLocal();
    final overdue = due != null && due.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: Gl.gap),
      child: Container(
        padding: const EdgeInsets.all(Gl.gutter),
        decoration: BoxDecoration(
          color: Gl.surface,
          borderRadius: BorderRadius.circular(Gl.rTile),
          boxShadow: Gl.lift,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlGlyph(
                  icon: LucideIcons.fileText,
                  tint: overdue ? Gl.blush : Gl.amber,
                  foreground: overdue ? Gl.blushInk : Gl.amberInk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice['number'] as String? ?? 'Tagihan', style: Gl.headline),
                      const SizedBox(height: 3),
                      Text(
                        due == null
                            ? 'Tanpa jatuh tempo'
                            : overdue
                                ? 'Lewat jatuh tempo ${dateLabel(due)}'
                                : 'Jatuh tempo ${dateLabel(due)}',
                        style: Gl.footnote.copyWith(
                          color: overdue ? Gl.blushInk : Gl.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(rupiah(invoice['total_rp']), style: Gl.amount),
              ],
            ),
            const SizedBox(height: 14),
            GlButton(label: 'Bayar sekarang', onPressed: onPay, busy: busy),
          ],
        ),
      ),
    );
  }
}
