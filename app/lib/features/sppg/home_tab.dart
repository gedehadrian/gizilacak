import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';
import 'batches_tab.dart';
import 'new_delivery.dart';
import 'policy_page.dart';
import '../billing/billing_page.dart';

class SppgHomeTab extends StatefulWidget {
  const SppgHomeTab({super.key});

  @override
  State<SppgHomeTab> createState() => _SppgHomeTabState();
}

class _SppgHomeTabState extends State<SppgHomeTab> {
  bool loading = true;
  String? error;
  int draftBatches = 0;
  int readyBatches = 0;
  int draftDeliveries = 0;
  int sentDeliveries = 0;
  bool entitled = false;
  bool hasPolicy = true;
  List<Map<String, dynamic>> links = const [];

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
      final batches = await session.api.batches(tenantId);
      final dels = await session.api.deliveries(tenantId: tenantId);
      final sub = await session.api.activeSubscription(tenantId);
      final schools = await session.api.linkedSchools(tenantId);
      final policy = await session.api.activePolicy(tenantId);
      if (!mounted) return;
      setState(() {
        draftBatches = batches.where((b) => b['status'] == 'draft').length;
        readyBatches = batches.where((b) => b['status'] == 'ready').length;
        draftDeliveries = dels.where((d) => d['status'] == 'draft').length;
        sentDeliveries = dels.where((d) => d['status'] == 'dispatched').length;
        entitled = sub != null;
        hasPolicy = policy != null;
        links = schools;
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

  Future<void> _linkSchool() async {
    final session = SessionScope.of(context);
    if (session.schools.isEmpty) {
      await showGlError(
        context,
        'Akun ini belum punya sekolah. Buat sekolah dulu, lalu hubungkan dari sini.',
      );
      return;
    }
    final school = await showGlSheet<OrgScope>(
      context: context,
      builder: (ctx) => GlSheet(
        title: const Text('Hubungkan sekolah'),
        message: const Text(
          'Sekolah masih harus menerima undangan agar kiriman bisa dikirim.',
        ),
        actions: [
          for (final s in session.schools)
            GlSheetAction(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text(s.name),
            ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
      ),
    );
    if (school == null || !mounted) return;
    try {
      await session.api.linkOwnSchool(
        tenantId: session.current!.id,
        schoolId: school.id,
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    }
  }

  Future<void> _openPolicy() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const PolicyPage()),
    );
    await _load();
  }

  Future<void> _newBatch() async {
    if (!hasPolicy) {
      await _openPolicy();
      return;
    }
    await startNewBatch(context);
    await _load();
  }

  Future<void> _openBilling() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const BillingPage()),
    );
    await _load();
  }

  Future<void> _newDelivery() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => const NewDeliveryPage()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final org = SessionScope.of(context).current!;
    final activeSchools = links.where((r) => r['status'] == 'active').length;

    return GlSliver(
      title: org.name,
      subtitle: org.code.isEmpty ? 'SPPG' : 'SPPG · ${org.code}',
      badge: monogram(org.name),
      onRefresh: _load,
      children: [
        if (error != null) GlNotice(error!),
        if (loading && links.isEmpty && error == null)
          const GlLoading()
        else ...[
          if (!hasPolicy)
            GlTile(
              leading: const GlGlyph(
                icon: LucideIcons.triangleAlert,
                tint: Gl.blush,
                foreground: Gl.blushInk,
              ),
              title: 'Kebijakan konsumsi belum ada',
              subtitle: 'Batch produksi belum bisa dibuat. Ketuk untuk mengatur.',
              chevron: true,
              onTap: _openPolicy,
            ),
          GlHero(
            caption: 'Sedang dalam perjalanan',
            value: '$sentDeliveries',
            unit: sentDeliveries == 1 ? 'kiriman' : 'kiriman',
            footer: 'Terpantau dari dapur sampai diterima sekolah.',
            chips: [
              GlHeroChip(label: 'draf produksi', value: '$draftBatches'),
              GlHeroChip(label: 'siap kirim', value: '$readyBatches'),
              GlHeroChip(label: 'kiriman draf', value: '$draftDeliveries'),
            ],
          ),
          const SizedBox(height: Gl.stack),
          Padding(
            padding: const EdgeInsets.only(bottom: Gl.stack),
            child: Row(
              children: [
                Expanded(
                  child: GlStatPill(
                    label: 'Langganan',
                    value: entitled ? 'Aktif' : 'Belum aktif',
                    tint: entitled ? Gl.mint : Gl.amber,
                    foreground: entitled ? Gl.mintInk : Gl.amberInk,
                  ),
                ),
                const SizedBox(width: Gl.gap),
                Expanded(
                  child: GlStatPill(
                    label: 'Sekolah aktif',
                    value: '$activeSchools',
                    tint: Gl.lilac,
                    foreground: Gl.primary,
                  ),
                ),
              ],
            ),
          ),
          if (!entitled)
            GlTile(
              leading: const GlGlyph(
                icon: LucideIcons.creditCard,
                tint: Gl.amber,
                foreground: Gl.amberInk,
              ),
              title: 'Langganan belum aktif',
              subtitle: 'Kiriman belum bisa didispatch. Ketuk untuk membayar.',
              chevron: true,
              onTap: _openBilling,
            ),
          const GlSectionHead('Aksi cepat'),
          GlQuickRow(
            children: [
              GlQuickTile(
                icon: LucideIcons.flame,
                label: 'Batch baru',
                tint: Gl.amber,
                foreground: Gl.amberInk,
                onTap: _newBatch,
              ),
              GlQuickTile(
                icon: LucideIcons.package,
                label: 'Kiriman',
                onTap: _newDelivery,
              ),
              GlQuickTile(
                icon: LucideIcons.building2,
                label: 'Sekolah',
                tint: Gl.mint,
                foreground: Gl.mintInk,
                onTap: _linkSchool,
              ),
            ],
          ),
          GlSectionHead(
            'Sekolah terhubung',
            actionLabel: 'Hubungkan',
            onAction: _linkSchool,
          ),
          if (links.isEmpty)
            const GlEmpty(
              icon: LucideIcons.building2,
              message: 'Belum ada sekolah terhubung. Hubungkan dulu sebelum membuat kiriman.',
            )
          else
            for (final row in links)
              GlTile(
                leading: GlGlyph(
                  icon: LucideIcons.building2,
                  tint: tintForTone(toneForStatus(row['status'] as String? ?? '')).tint,
                  foreground: tintForTone(toneForStatus(row['status'] as String? ?? '')).ink,
                ),
                title: (row['schools'] as Map?)?['name'] as String? ?? 'Sekolah',
                subtitle: (row['schools'] as Map?)?['school_code'] as String?,
                trailing: StatusChip(
                  statusLabel(row['status'] as String? ?? ''),
                  tone: toneForStatus(row['status'] as String? ?? ''),
                ),
              ),
        ],
      ],
    );
  }
}
