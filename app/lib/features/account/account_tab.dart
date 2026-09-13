import 'package:flutter/cupertino.dart';

import '../../state/session.dart';
import '../../theme/apple.dart';
import '../audit/audit_page.dart';
import '../billing/billing_page.dart';
import '../finance/finance_page.dart';
import '../incidents/incidents_page.dart';
import '../platform/platform_page.dart';
import '../reports/reports_page.dart';
import '../sppg/policy_page.dart';
import '../sppg/recipes_page.dart';
import '../team/team_page.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  bool isPlatformAdmin = false;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SessionScope dibaca di dalam _checkPlatform(), dan InheritedWidget
    // baru boleh dibaca setelah initState selesai.
    if (_started) return;
    _started = true;
    _checkPlatform();
  }

  Future<void> _checkPlatform() async {
    final session = SessionScope.of(context);
    final userId = session.user?.id;
    if (userId == null) return;
    try {
      final admin = await session.api.isPlatformAdmin(userId);
      if (mounted && admin != isPlatformAdmin) {
        setState(() => isPlatformAdmin = admin);
      }
    } catch (_) {
      // Bukan operator platform, atau barisnya tidak terbaca. Diamkan —
      // bagian ini memang hanya muncul untuk yang berhak.
    }
  }

  void _open(Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final org = session.current;
    final email = session.user?.email ?? 'Tanpa email';

    return GlSliver(
      title: 'Akun',
      children: [
        GlCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: Gl.lilac, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  monogram(org?.name ?? email),
                  style: const TextStyle(
                    fontFamily: Gl.font,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Gl.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org?.name ?? 'Belum memilih organisasi',
                      style: Gl.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: Gl.footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (org != null)
                StatusChip(org.isTenant ? 'SPPG' : 'Sekolah', tone: ChipTone.neutral),
            ],
          ),
        ),
        if (org != null)
          GlSection(
            header: 'Organisasi',
            children: [
              GlRow(
                leading: const GlGlyph(icon: CupertinoIcons.person_2),
                title: 'Peran',
                value: org.role,
                chevron: false,
              ),
              if (org.code.isNotEmpty)
                GlRow(
                  leading: const GlGlyph(icon: CupertinoIcons.number),
                  title: org.isTenant ? 'Kode SPPG' : 'Kode sekolah',
                  value: org.code,
                  chevron: false,
                ),
              GlRow(
                leading: const GlGlyph(icon: CupertinoIcons.person_2_square_stack),
                title: 'Tim',
                subtitle: 'Anggota dan undangan',
                onTap: () => _open(const TeamPage()),
              ),
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.arrow_2_squarepath,
                  tint: Gl.mint,
                  foreground: Gl.mintInk,
                ),
                title: 'Ganti organisasi',
                onTap: session.clearOrg,
              ),
            ],
          ),
        if (org != null && org.isTenant)
          GlSection(
            header: 'Produksi',
            footer: 'Kebijakan konsumsi menentukan batas waktu setiap batch. '
                'Harus ada sebelum batch pertama dibuat.',
            children: [
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.square_list,
                  tint: Gl.lilac,
                  foreground: Gl.primary,
                ),
                title: 'Menu',
                subtitle: 'Gizi, bahan, dan alergen',
                onTap: () => _open(const RecipesPage()),
              ),
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.clock,
                  tint: Gl.amber,
                  foreground: Gl.amberInk,
                ),
                title: 'Kebijakan konsumsi',
                onTap: () => _open(const PolicyPage()),
              ),
            ],
          ),
        if (org != null)
          GlSection(
            header: 'Catatan',
            footer: org.isTenant
                ? 'Jejak audit hanya bisa dibuka oleh owner dan manager.'
                : 'Laporkan kiriman bermasalah agar SPPG bisa menindaklanjuti.',
            children: [
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.exclamationmark_bubble,
                  tint: Gl.blush,
                  foreground: Gl.blushInk,
                ),
                title: 'Insiden',
                onTap: () => _open(const IncidentsPage()),
              ),
              if (org.isTenant)
                GlRow(
                  leading: const GlGlyph(
                    icon: CupertinoIcons.money_dollar_circle,
                    tint: Gl.mint,
                    foreground: Gl.mintInk,
                  ),
                  title: 'Keuangan',
                  subtitle: 'Biaya operasional',
                  onTap: () => _open(const FinancePage()),
                ),
              if (org.isTenant)
                GlRow(
                  leading: const GlGlyph(icon: CupertinoIcons.arrow_down_doc),
                  title: 'Laporan',
                  subtitle: 'Unduh CSV kiriman dan keuangan',
                  onTap: () => _open(const ReportsPage()),
                ),
              if (org.isTenant)
                GlRow(
                  leading: const GlGlyph(icon: CupertinoIcons.doc_text_search),
                  title: 'Jejak audit',
                  onTap: () => _open(const AuditPage()),
                ),
            ],
          ),
        if (org != null && org.isTenant)
          GlSection(
            header: 'Langganan',
            footer: 'Tagihan dibayar lewat Midtrans di dalam aplikasi ini.',
            children: [
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.creditcard,
                  tint: Gl.amber,
                  foreground: Gl.amberInk,
                ),
                title: 'Langganan & tagihan',
                onTap: () => _open(const BillingPage()),
              ),
            ],
          ),
        if (isPlatformAdmin)
          GlSection(
            header: 'Operator GiziLacak',
            footer: 'Bagian ini hanya terlihat oleh operator platform.',
            children: [
              GlRow(
                leading: const GlGlyph(
                  icon: CupertinoIcons.chart_bar_square,
                  tint: Gl.lilac,
                  foreground: Gl.primary,
                ),
                title: 'Konsol platform',
                subtitle: 'SPPG, tagihan, paket, biaya',
                onTap: () => _open(const PlatformPage()),
              ),
            ],
          ),
        GlSection(
          children: [
            GlActionRow(label: 'Keluar', tone: Gl.red, onTap: session.signOut),
          ],
        ),
      ],
    );
  }
}
