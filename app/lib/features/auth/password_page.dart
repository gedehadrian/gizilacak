import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/session.dart';
import '../../theme/apple.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key, this.recovery = false});
  final bool recovery;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  bool changed = false;
  String? message;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final session = SessionScope.of(context);
    try {
      if (widget.recovery) {
        if (!changed) {
          if (password.text.length < 8) {
            throw const FormatException('Kata sandi minimal 8 karakter.');
          }
          if (password.text != confirmation.text) {
            throw const FormatException('Konfirmasi kata sandi tidak cocok.');
          }
          if (!session.recoveringPassword ||
              session.client.auth.currentSession == null) {
            throw const FormatException(
              'Sesi pemulihan sudah berakhir. Minta tautan baru.',
            );
          }
          await session.client.auth.updateUser(
            UserAttributes(password: password.text),
          );
          changed = true;
          if (mounted) {
            setState(
              () => message =
                  'Kata sandi berhasil diganti. Masuk dengan kata sandi baru.',
            );
          }
        }
        await session.signOut();
      } else {
        final address = email.text.trim();
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
          throw const FormatException('Masukkan alamat email yang valid.');
        }
        await session.client.auth.resetPasswordForEmail(
          address,
          redirectTo: kIsWeb
              ? Uri.base.replace(query: '', fragment: '').toString()
              : 'gizilacak://reset-password',
        );
        if (mounted) {
          setState(
            () => message =
                'Jika email terdaftar, tautan pemulihan akan dikirim. Buka di perangkat dan aplikasi tempat Anda meminta tautan.',
          );
        }
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = changed
              ? 'Kata sandi sudah diganti. Coba keluar lagi untuk masuk ulang.'
              : 'Permintaan gagal. Periksa koneksi lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: Gl.bg,
    child: SafeArea(
      child: GlPhone(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Gl.gutter,
            28,
            Gl.gutter,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(
              widget.recovery ? 'Ganti kata sandi' : 'Lupa kata sandi',
              style: Gl.largeTitle,
            ),
            const SizedBox(height: 12),
            Text(
              widget.recovery
                  ? 'Masukkan kata sandi baru untuk akun Anda.'
                  : 'Kami akan mengirim tautan pemulihan lewat email.',
              style: Gl.body,
            ),
            const SizedBox(height: Gl.stack),
            if (message != null) GlNotice(message!),
            if (error != null) GlNotice(error!),
            if (!changed)
              GlSection(
                children: widget.recovery
                    ? [
                        GlTextRow(
                          controller: password,
                          placeholder: 'Kata sandi baru',
                          obscure: true,
                          autofill: const [AutofillHints.newPassword],
                        ),
                        GlTextRow(
                          controller: confirmation,
                          placeholder: 'Ulangi kata sandi baru',
                          obscure: true,
                        ),
                      ]
                    : [
                        GlTextRow(
                          controller: email,
                          placeholder: 'Email',
                          keyboardType: TextInputType.emailAddress,
                          autofill: const [AutofillHints.email],
                        ),
                      ],
              ),
            GlButton(
              label: changed
                  ? 'Keluar dan masuk ulang'
                  : widget.recovery
                  ? 'Simpan kata sandi'
                  : 'Kirim tautan pemulihan',
              busy: busy,
              onPressed: submit,
            ),
            GlButton(
              label: 'Kembali ke masuk',
              filled: false,
              onPressed: busy
                  ? null
                  : () async {
                      if (widget.recovery) {
                        try {
                          await SessionScope.of(context).signOut();
                        } catch (_) {
                          if (mounted) {
                            setState(() => error = 'Gagal keluar. Coba lagi.');
                          }
                        }
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
