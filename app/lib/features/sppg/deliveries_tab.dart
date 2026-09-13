import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'delivery_page.dart';
import 'new_delivery.dart';

class DeliveriesTab extends StatefulWidget {
  const DeliveriesTab({super.key});

  @override
  State<DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<DeliveriesTab> {
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
      final data = await session.api.deliveries(tenantId: session.current!.id);
      if (mounted) {
        setState(() {
          items = data;
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

  Future<void> _open(String deliveryId) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => DeliveryPage(deliveryId: deliveryId)),
    );
    await _load();
  }

  Future<void> _create() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const NewDeliveryPage()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = groupByDay(items, 'created_at', toLocal: true);
    final moving = items.where((d) => d['status'] == 'dispatched').length;
    final draft = items.where((d) => d['status'] == 'draft').length;

    return GlSliver(
      title: 'Kiriman',
      onRefresh: _load,
      trailing: GlCircleButton(
        icon: CupertinoIcons.add,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _create,
      ),
      children: [
        if (error != null) GlNotice(error!),
        if (loading && items.isEmpty)
          const GlLoading()
        else if (items.isEmpty)
          GlEmpty(
            icon: CupertinoIcons.cube_box,
            message: 'Belum ada kiriman. Satu QR berlaku untuk satu pengiriman ke satu '
                'sekolah, dan boleh dicetak ulang di setiap dus.',
            actionLabel: 'Buat kiriman',
            onAction: _create,
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Gl.stack),
            child: Row(
              children: [
                Expanded(
                  child: GlStatPill(
                    label: 'Dalam perjalanan',
                    value: '$moving',
                    tint: Gl.lilac,
                    foreground: Gl.primary,
                  ),
                ),
                const SizedBox(width: Gl.gap),
                Expanded(
                  child: GlStatPill(
                    label: 'Masih draf',
                    value: '$draft',
                    tint: Gl.amber,
                    foreground: Gl.amberInk,
                  ),
                ),
              ],
            ),
          ),
          for (final day in days) ...[
            GlSectionHead(day.label),
            for (final delivery in day.rows)
              _DeliveryTile(
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

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery, required this.onTap});

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
      title: (delivery['schools'] as Map?)?['name'] as String? ?? 'Sekolah',
      subtitle: delivery['code'] as String?,
      trailing: StatusChip(statusLabel(status), tone: tone),
      chevron: true,
      onTap: onTap,
    );
  }
}
