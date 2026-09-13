import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'billing_page.dart' show rupiah;

/// Memilih paket lalu menerbitkan tagihannya.
///
/// Harga tidak pernah dikirim dari sini — layar ini hanya menunjuk versi paket,
/// dan server mengambil nominalnya dari katalog yang sudah terbit.
class PlanPickerPage extends StatefulWidget {
  const PlanPickerPage({super.key, required this.renewal});

  /// Perpanjangan kalau SPPG sudah pernah berlangganan.
  final bool renewal;

  @override
  State<PlanPickerPage> createState() => _PlanPickerPageState();
}

class _PlanPickerPageState extends State<PlanPickerPage> {
  List<Map<String, dynamic>> plans = const [];
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
      final rows = await session.api.availablePlans();
      if (mounted) {
        setState(() {
          plans = rows;
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

  Future<void> _choose(Map<String, dynamic> plan, Map<String, dynamic> version) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('${plan['name']} v${version['version']}'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(
                '${rupiah(version['price_rp'])} per bulan',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '${version['delivery_limit']} kiriman · '
                '${version['school_limit']} sekolah · '
                '${version['staff_limit']} staf',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tagihan terbit sekarang dan jatuh tempo dalam 7 hari. '
                'Langganan aktif setelah pembayaran dikonfirmasi.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terbitkan tagihan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busy = true);
    final session = SessionScope.of(context);
    try {
      await session.api.createInvoiceFromPlan(
        tenantId: session.current!.id,
        planVersionId: version['id'] as String,
        renewal: widget.renewal,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Kebutuhan yang tidak tertampung paket mana pun diarahkan ke percakapan
  /// langsung, bukan dibiarkan buntu di layar ini.
  Future<void> _askCustom() async {
    final org = SessionScope.of(context).current;
    final message = Uri.encodeComponent(
      'Halo GiziLacak, saya dari ${org?.name ?? 'SPPG'}'
      '${org?.code.isNotEmpty == true ? ' (${org!.code})' : ''}. '
      'Kebutuhan kami belum tertampung paket yang ada, '
      'dan saya ingin menanyakan paket khusus.',
    );
    final uri = Uri.parse(
      'https://wa.me/${AppConfig.supportWhatsappDigits}?text=$message',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await showGlError(context, 'Tidak bisa membuka WhatsApp di perangkat ini.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlDetail(
      title: widget.renewal ? 'Perpanjang paket' : 'Pilih paket',
      loading: loading && plans.isEmpty,
      children: [
        if (error != null) GlNotice(error!),
        if (busy) const GlLoading(),
        if (plans.isEmpty && !loading)
          const GlEmpty(
            icon: CupertinoIcons.square_list,
            message: 'Belum ada paket yang terbit. Hubungi pengelola GiziLacak.',
          )
        else
          for (final plan in plans)
            GlSection(
              header: plan['name'] as String? ?? 'Paket',
              footer: (plan['description'] as String?)?.trim().isEmpty ?? true
                  ? null
                  : plan['description'] as String,
              children: [
                for (final version in plan['plan_versions'] as List)
                  GlRow(
                    leading: const GlGlyph(icon: CupertinoIcons.creditcard),
                    title: rupiah((version as Map)['price_rp']),
                    subtitle: '${version['delivery_limit']} kiriman · '
                        '${version['school_limit']} sekolah · '
                        '${version['staff_limit']} staf',
                    trailing: Text('v${version['version']}', style: Gl.footnote),
                    onTap: busy
                        ? null
                        : () => _choose(plan, Map<String, dynamic>.from(version)),
                  ),
              ],
            ),
        if (AppConfig.hasSupportWhatsapp)
          GlSection(
            header: 'Kebutuhan khusus',
            footer: 'Sekolah lebih banyak, kiriman di luar batas paket, atau '
                'skema kerja sama tersendiri — dibicarakan langsung.',
            children: [
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.chat_bubble_2,
                  tint: Gl.mint,
                  foreground: Gl.mintInk,
                ),
                title: 'Hubungi lewat WhatsApp',
                subtitle: 'Untuk kebutuhan di luar ketiga paket di atas',
                onTap: _askCustom,
              ),
            ],
          ),
        const GlFootnote(
          'Harga diambil dari katalog resmi di server, bukan dari aplikasi ini. '
          'Pembayaran diproses Midtrans, dan langganan aktif setelah Midtrans '
          'mengonfirmasi.',
        ),
      ],
    );
  }
}
