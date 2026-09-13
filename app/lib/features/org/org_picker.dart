import 'package:flutter/cupertino.dart';

import '../../state/session.dart';
import '../../theme/apple.dart';
import '../team/join_page.dart';
import 'create_org.dart';

class OrgPickerPage extends StatelessWidget {
  const OrgPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final hasAny = session.tenants.isNotEmpty || session.schools.isNotEmpty;

    Future<void> create(OrgKind kind) async {
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => CreateOrgPage(kind: kind)),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: GlPhone(
        child: GlSliver(
          title: 'Organisasi',
          subtitle: 'Pilih tempat Anda bekerja',
          onRefresh: session.refreshMemberships,
          children: [
            if (session.bootError != null) GlNotice(session.bootError!),
            if (!hasAny)
              const GlEmpty(
                icon: LucideIcons.building2,
                message: 'Belum ada organisasi di akun ini. Buat SPPG atau sekolah, atau '
                    'terima undangan yang dikirim ke email Anda.',
              ),
            if (session.tenants.isNotEmpty) ...[
              const GlSectionHead('SPPG'),
              for (final org in session.tenants)
                _OrgTile(org: org, onTap: () => session.select(org)),
              const SizedBox(height: Gl.stack - Gl.gap),
            ],
            if (session.schools.isNotEmpty) ...[
              const GlSectionHead('Sekolah'),
              for (final org in session.schools)
                _OrgTile(org: org, onTap: () => session.select(org)),
              const SizedBox(height: Gl.stack - Gl.gap),
            ],
            GlSection(
              footer: 'Paket berlangganan dan invoice diatur di situs web, bukan di aplikasi.',
              children: [
                GlRow(
                  leading: const GlGlyph(icon: LucideIcons.plus),
                  title: 'Buat SPPG',
                  onTap: () => create(OrgKind.tenant),
                ),
                GlRow(
                  leading: const GlGlyph(
                    icon: LucideIcons.plus,
                    tint: Gl.mint,
                    foreground: Gl.mintInk,
                  ),
                  title: 'Buat sekolah',
                  onTap: () => create(OrgKind.school),
                ),
                GlRow(
                  leading: const GlGlyph(
                    icon: LucideIcons.mail,
                    tint: Gl.amber,
                    foreground: Gl.amberInk,
                  ),
                  title: 'Terima undangan',
                  subtitle: 'Punya token dari SPPG atau sekolah',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const JoinPage()),
                  ),
                ),
              ],
            ),
            GlSection(
              children: [
                GlActionRow(label: 'Keluar', tone: Gl.red, onTap: session.signOut),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrgTile extends StatelessWidget {
  const _OrgTile({required this.org, required this.onTap});

  final OrgScope org;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: org.isTenant ? Gl.lilac : Gl.mint,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          monogram(org.name),
          style: TextStyle(
            fontFamily: Gl.font,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: org.isTenant ? Gl.primary : Gl.mintInk,
          ),
        ),
      ),
      title: org.name,
      subtitle: org.code.isEmpty ? org.role : '${org.code} · ${org.role}',
      chevron: true,
      onTap: onTap,
    );
  }
}
