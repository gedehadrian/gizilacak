import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mengambil isi sebuah blok yang diindentasi dua spasi, dari baris pembuka
/// sampai baris penutup `  }` yang pertama.
String? _blockAfter(String source, RegExp opener) {
  final match = opener.firstMatch(source);
  if (match == null) return null;
  final start = match.end;
  final end = source.indexOf('\n  }', start);
  return end == -1 ? source.substring(start) : source.substring(start, end);
}

void main() {
  // Regresi nyata: layar memanggil SessionScope.of(context) dari initState,
  // dan Flutter melempar
  //   "dependOnInheritedWidgetOfExactType<SessionScope>() ... was called
  //    before _SppgHomeTabState.initState() completed."
  // Akibatnya tab Hari ini gagal dipasang tepat setelah pengguna berhasil
  // masuk. InheritedWidget baru boleh dibaca di didChangeDependencies.
  //
  // Pemeriksaan ini dilakukan di tingkat sumber karena menguji tiap layar satu
  // per satu sebagai widget memerlukan klien Supabase tiruan, dan timer
  // auto-refresh miliknya membuat test menggantung.
  test('tidak ada initState yang membaca SessionScope, langsung atau lewat '
      'method yang dipanggilnya', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('SessionScope.of')) continue;

      final body = _blockAfter(source, RegExp(r'void initState\(\) \{'));
      if (body == null) continue;

      if (body.contains('SessionScope.of')) {
        offenders.add('${entity.path}: initState membacanya langsung');
        continue;
      }

      // Panggilan seperti `_load();` di dalam initState: telusuri isinya.
      for (final call in RegExp(r'\b(_[A-Za-z0-9]+)\(\)').allMatches(body)) {
        final name = call.group(1)!;
        final callee = _blockAfter(
          source,
          RegExp('(?:Future<void>|void)\\s+$name\\([^)]*\\)\\s*(?:async\\s*)?\\{'),
        );
        if (callee != null && callee.contains('SessionScope.of')) {
          offenders.add('${entity.path}: initState memanggil $name(), '
              'dan $name() membaca SessionScope');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Pindahkan pemanggilannya ke didChangeDependencies dengan '
          'penjaga sekali-jalan:\n${offenders.join('\n')}',
    );
  });
}
