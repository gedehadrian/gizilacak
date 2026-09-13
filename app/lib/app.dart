import 'package:flutter/cupertino.dart';

import 'features/auth/login_page.dart';
import 'features/auth/password_page.dart';
import 'features/org/org_picker.dart';
import 'features/school/school_shell.dart';
import 'features/sppg/sppg_shell.dart';
import 'state/session.dart';
import 'theme/apple.dart';

class GiziApp extends StatefulWidget {
  const GiziApp({super.key, required this.session});

  final AppSession session;

  @override
  State<GiziApp> createState() => _GiziAppState();
}

class _GiziAppState extends State<GiziApp> {
  @override
  void initState() {
    super.initState();
    widget.session.boot();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: CupertinoApp(
        title: 'GiziLacak',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: Gl.primary,
          scaffoldBackgroundColor: Gl.bg,
          barBackgroundColor: Gl.bg,
          applyThemeToAll: true,
          textTheme: CupertinoTextThemeData(
            primaryColor: Gl.primary,
            textStyle: Gl.body,
            actionTextStyle: TextStyle(
              fontFamily: Gl.font,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Gl.primary,
            ),
            navTitleTextStyle: Gl.headline,
            navLargeTitleTextStyle: Gl.largeTitle,
            navActionTextStyle: TextStyle(
              fontFamily: Gl.font,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Gl.primary,
            ),
            tabLabelTextStyle: TextStyle(
              fontFamily: Gl.font,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            pickerTextStyle: Gl.body,
            dateTimePickerTextStyle: Gl.body,
          ),
        ),
        builder: (context, child) => ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) => widget.session.recoveringPassword
              ? Navigator(
                  key: const ValueKey('password-recovery'),
                  onGenerateRoute: (_) => CupertinoPageRoute<void>(
                    builder: (_) => const PasswordPage(recovery: true),
                  ),
                )
              : child!,
        ),
        home: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) {
            if (!widget.session.ready) return const _Booting();
            if (widget.session.user == null) return const LoginPage();
            if (widget.session.current == null) return const OrgPickerPage();
            return widget.session.current!.isTenant
                ? const SppgShell()
                : const SchoolShell();
          },
        ),
      ),
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        backgroundColor: Gl.bg,
        child: SafeArea(
          child: GlPhone(
            child: Padding(
              padding: EdgeInsets.fromLTRB(Gl.gutter, 64, Gl.gutter, Gl.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gl.gutter),
                    child: Text('Belum dikonfigurasi', style: Gl.largeTitle),
                  ),
                  SizedBox(height: 24),
                  GlSection(
                    footer: 'Isi SUPABASE_URL dan SUPABASE_ANON_KEY publik, lalu jalankan '
                        'ulang aplikasi.',
                    children: [
                      GlRow(
                        title: 'Salin app/.env.example',
                        subtitle: 'menjadi app/.env',
                        chevron: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
