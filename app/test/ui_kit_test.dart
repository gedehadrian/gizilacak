import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/theme/apple.dart';

void main() {
  testWidgets('dialog returns action and long sheet fits a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await tester.runAsync(icons.load);
    final boundary = GlobalKey();
    late BuildContext context;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: CupertinoApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const ColoredBox(
                color: Gl.bg,
                child: Center(child: Text('GiziLacak', style: Gl.largeTitle)),
              );
            },
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('UI_REVIEW')) return;
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/ui-review').createSync(recursive: true);
        File(
          'build/ui-review/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final result = showGlDialog<bool>(
      context: context,
      builder: (ctx) => GlDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda dapat masuk kembali kapan saja.'),
        actions: [
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          GlDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await capture('dialog');
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(await result, true);
    final sheet = showGlSheet<int>(
      context: context,
      builder: (ctx) => GlSheet(
        title: const Text('Pilih sekolah'),
        actions: [
          for (var i = 0; i < 16; i++)
            GlSheetAction(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text('Sekolah ${i + 1}'),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await capture('sheet');
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Sekolah 16'), 200);
    await tester.tap(find.text('Sekolah 16'));
    await tester.pumpAndSettle();
    expect(await sheet, 15);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: const CupertinoApp(
          home: ColoredBox(
            color: Gl.bg,
            child: Center(child: GlSpinner()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await capture('loading');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('floating bar switches tabs and preserves entered text', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoTabScaffold(
          tabBar: GlTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.house),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.userRound),
                label: 'Akun',
              ),
            ],
          ),
          tabBuilder: (_, index) => CupertinoTabView(
            builder: (_) => CupertinoPageScaffold(
              child: Center(
                child: index == 0
                    ? const GlInput(placeholder: 'Nama')
                    : const Text('Profil akun'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Gizi');
    await tester.tap(find.text('Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Profil akun'), findsOneWidget);
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    expect(find.text('Gizi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
