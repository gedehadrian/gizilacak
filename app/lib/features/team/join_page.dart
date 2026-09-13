import 'package:flutter/cupertino.dart';

import '../../data/api.dart';
import '../../state/session.dart';
import '../../theme/apple.dart';

/// Menerima undangan dari dalam app. Staf menempelkan token atau seluruh
/// tautan undangan yang mereka terima lewat email.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  final token = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => busy = true);
    final session = SessionScope.of(context);
    try {
      await session.api.acceptInvitation(token.text);
      await session.refreshMemberships();
      if (!mounted) return;
      Navigator.pop(context);
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Undangan diterima'),
          content: const Text('Organisasinya sekarang muncul di daftar Anda.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = SessionScope.of(context).user?.email ?? 'akun ini';

    return GlDetail(
      title: 'Terima undangan',
      bottomBar: GlButton(
        label: 'Terima undangan',
        onPressed: busy ? null : _accept,
        busy: busy,
      ),
      children: [
        GlSection(
          footer: 'Boleh menempelkan tokennya saja, atau seluruh tautan undangan.',
          children: [
            GlTextRow(
              controller: token,
              placeholder: 'Token atau tautan undangan',
            ),
          ],
        ),
        GlFootnote(
          'Undangan hanya bisa diterima oleh akun dengan email yang sama persis '
          'dengan yang diundang. Anda sedang masuk sebagai $email — kalau undangannya '
          'ditujukan ke email lain, keluar dulu lalu masuk dengan email itu.',
        ),
      ],
    );
  }
}
