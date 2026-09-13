import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Anggota organisasi dan undangan yang masih berjalan.
///
/// Nama anggota lain tidak bisa ditampilkan: `profiles_select` hanya
/// mengizinkan membaca profil sendiri. Yang tampil peran dan statusnya.
class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  List<Map<String, dynamic>> members = const [];
  List<Map<String, dynamic>> invites = const [];
  bool loading = true;
  String? error;

  static const tenantRoles = ['manager', 'operator', 'finance', 'viewer'];
  static const schoolRoles = ['admin', 'staff'];

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
    final org = session.current!;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final rows = org.isTenant
          ? await session.api.tenantMembers(org.id)
          : await session.api.schoolMembers(org.id);
      final pending = await session.api.invitations(
        tenantId: org.isTenant ? org.id : null,
        schoolId: org.isTenant ? null : org.id,
      );
      if (!mounted) return;
      setState(() {
        members = rows;
        invites = pending;
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

  Future<void> _invite() async {
    final session = SessionScope.of(context);
    final org = session.current!;
    final roles = org.isTenant ? tenantRoles : schoolRoles;

    final email = TextEditingController();
    var role = roles.first;

    final confirmed = await showGlDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => GlDialog(
          title: const Text('Undang anggota'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              GlInput(
                controller: email,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              GlSegments<String>(
                groupValue: role,
                children: {
                  for (final r in roles)
                    r: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Text(r, style: const TextStyle(fontSize: 12)),
                    ),
                },
                onValueChanged: (v) => setDialog(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            GlDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            GlDialogAction(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Undang'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await session.api.createInvitation(
        tenantId: org.isTenant ? org.id : null,
        schoolId: org.isTenant ? null : org.id,
        email: email.text,
        role: role,
        invitedBy: session.user!.id,
      );
      if (!mounted) return;
      await _showToken(token, email.text.trim());
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  Future<void> _showToken(String token, String email) async {
    final link = '${AppConfig.webAppUrl}/undangan/$token';
    await showGlDialog<void>(
      context: context,
      builder: (ctx) => GlDialog(
        title: const Text('Bagikan token ini'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(
                'Kirim ke $email. Token hanya muncul sekali — yang tersimpan di '
                'server cuma sidiknya, bukan tokennya.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(token, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          GlDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salin token'),
          ),
          GlDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salin tautan'),
          ),
          GlDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> invite) async {
    final confirmed = await showGlSheet<bool>(
      context: context,
      builder: (ctx) => GlSheet(
        title: Text('Cabut undangan ${invite['email']}'),
        actions: [
          GlSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut'),
          ),
        ],
        cancelButton: GlSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SessionScope.of(context).api.revokeInvitation(invite['id'] as String);
      await _load();
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final org = session.current!;
    final me = session.user?.id;
    final open = invites.where(_isOpen).toList();
    final closed = invites.where((i) => !_isOpen(i)).toList();

    return GlDetail(
      title: 'Tim',
      subtitle: org.name,
      loading: loading && members.isEmpty,
      trailing: GlCircleButton(
        icon: LucideIcons.userRoundPlus,
        tint: Gl.primary,
        foreground: Gl.surface,
        onTap: _invite,
      ),
      children: [
        if (error != null) GlNotice(error!),
        GlHero(
          caption: 'Anggota aktif',
          value: '${members.where((m) => m['status'] == 'active').length}',
          unit: 'orang',
          footer: 'Undangan berlaku 7 hari sejak dibuat.',
          chips: [
            if (open.isNotEmpty) GlHeroChip(label: 'undangan terbuka', value: '${open.length}'),
          ],
        ),
        const SizedBox(height: Gl.stack),
        GlSection(
          header: 'Anggota',
          footer: 'Nama anggota lain tidak ditampilkan karena aturan privasi di '
              'database — setiap orang hanya boleh membaca profilnya sendiri.',
          children: [
            for (final member in members)
              GlRow(
                leading: GlGlyph(
                  icon: LucideIcons.userRound,
                  tint: member['user_id'] == me ? Gl.lilac : Gl.fill,
                  foreground: member['user_id'] == me ? Gl.primary : Gl.tertiary,
                ),
                title: member['user_id'] == me
                    ? '${session.user?.email ?? 'Saya'} (Anda)'
                    : 'Anggota',
                subtitle: member['role'] as String?,
                chevron: false,
                trailing: member['status'] == 'active'
                    ? null
                    : StatusChip(
                        statusLabel(member['status'] as String? ?? ''),
                        tone: ChipTone.neutral,
                      ),
              ),
          ],
        ),
        if (open.isNotEmpty) ...[
          const GlSectionHead('Undangan terbuka'),
          for (final invite in open)
            GlTile(
              leading: const GlGlyph(
                icon: LucideIcons.mail,
                tint: Gl.amber,
                foreground: Gl.amberInk,
              ),
              title: invite['email'] as String? ?? '—',
              subtitle: _expiry(invite),
              trailing: const StatusChip('Menunggu', tone: ChipTone.warn),
              chevron: true,
              onTap: () => _revoke(invite),
            ),
          const SizedBox(height: Gl.stack - Gl.gap),
        ],
        if (closed.isNotEmpty) ...[
          const GlSectionHead('Riwayat undangan'),
          for (final invite in closed)
            GlTile(
              leading: GlGlyph(
                icon: LucideIcons.mailOpen,
                tint: invite['accepted_at'] != null ? Gl.mint : Gl.fill,
                foreground: invite['accepted_at'] != null ? Gl.mintInk : Gl.tertiary,
              ),
              title: invite['email'] as String? ?? '—',
              subtitle: invite['role'] as String?,
              trailing: StatusChip(
                invite['accepted_at'] != null
                    ? 'Diterima'
                    : invite['revoked_at'] != null
                        ? 'Dicabut'
                        : 'Kedaluwarsa',
                tone: invite['accepted_at'] != null ? ChipTone.good : ChipTone.neutral,
              ),
            ),
        ],
      ],
    );
  }

  static bool _isOpen(Map<String, dynamic> invite) {
    if (invite['accepted_at'] != null || invite['revoked_at'] != null) return false;
    final expires = parseDate(invite['expires_at']);
    return expires != null && expires.isAfter(DateTime.now());
  }

  static String? _expiry(Map<String, dynamic> invite) {
    final expires = parseDate(invite['expires_at'])?.toLocal();
    if (expires == null) return invite['role'] as String?;
    final days = expires.difference(DateTime.now()).inDays;
    return '${invite['role']} · berlaku $days hari lagi';
  }
}
