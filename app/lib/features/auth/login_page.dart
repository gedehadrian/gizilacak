import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/session.dart';
import '../../theme/apple.dart';
import 'password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => busy = true);
    final session = SessionScope.of(context);
    try {
      if (signup) {
        final res = await session.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          // Tanpa ini Supabase memakai Site URL proyek, sehingga tautan
          // verifikasi mengarah ke situs, bukan kembali ke aplikasi.
          emailRedirectTo: kIsWeb
              ? Uri.base.replace(query: '', fragment: '').toString()
              : 'gizilacak://auth-callback',
        );
        if (!mounted) return;
        if (res.session == null) {
          await showGlDialog<void>(
            context: context,
            builder: (ctx) => GlDialog(
              title: const Text('Cek email'),
              content: const Text('Akun dibuat. Buka tautan verifikasi, lalu masuk di sini.'),
              actions: [
                GlDialogAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          if (mounted) setState(() => signup = false);
        }
      } else {
        await session.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) await showGlError(context, e.message);
    } catch (e) {
      if (mounted) await showGlError(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: SafeArea(
        child: GlPhone(
          child: AutofillGroup(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                Gl.gutter,
                28,
                Gl.gutter,
                28 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                GlHero(
                  caption: 'GiziLacak',
                  value: signup ? 'Buat akun' : 'Masuk',
                  footer: signup
                      ? 'Untuk staf SPPG dan sekolah. Siswa tidak perlu aplikasi ini.'
                      : 'Kelola produksi, kiriman, dan penerimaan porsi harian.',
                ),
                const SizedBox(height: Gl.stack),
                if (SessionScope.of(context).authError case final message?)
                  GlNotice(message),
                GlSection(
                  children: [
                    GlTextRow(
                      controller: email,
                      placeholder: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      autofill: const [AutofillHints.email],
                      prefixIcon: LucideIcons.mail,
                    ),
                    GlTextRow(
                      controller: password,
                      placeholder: 'Kata sandi',
                      obscure: true,
                      autofill: const [AutofillHints.password],
                      prefixIcon: LucideIcons.lockKeyhole,
                    ),
                  ],
                ),
                GlButton(
                  label: signup ? 'Buat akun' : 'Masuk',
                  onPressed: _submit,
                  busy: busy,
                ),
                if (!signup)
                  GlButton(
                    label: 'Lupa kata sandi',
                    filled: false,
                    onPressed: busy ? null : () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(builder: (_) => const PasswordPage()),
                    ),
                  ),
                const SizedBox(height: 4),
                GlButton(
                  label: signup ? 'Sudah punya akun' : 'Buat akun baru',
                  filled: false,
                  onPressed: busy ? null : () => setState(() => signup = !signup),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GlGlyph(
                      icon: LucideIcons.scanQrCode,
                      tint: Gl.mint,
                      foreground: Gl.mintInk,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Siswa memindai QR lewat kamera HP di browser — tanpa unduh '
                        'aplikasi dan tanpa akun.',
                        style: Gl.footnote,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
