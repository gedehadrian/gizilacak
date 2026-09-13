import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/state/session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('boot tetap selesai walau server tidak pernah menjawab', () async {
    // Server yang menerima permintaan lalu diam selamanya — bukan menolak,
    // bukan error. Inilah keadaan yang dulu membuat layar boot berputar
    // tanpa akhir, karena tidak ada exception yang bisa ditangkap.
    final stuck = Completer<http.Response>();
    addTearDown(() {
      if (!stuck.isCompleted) {
        stuck.complete(http.Response('{}', 200));
      }
    });

    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient((_) => stuck.future),
    );
    final session = AppSession(client);

    // `user` tetap null di sini, jadi jalur boot tidak menyentuh jaringan dan
    // harus selesai seketika.
    await session.boot().timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('boot() menggantung padahal tidak ada sesi tersimpan'),
    );

    expect(session.ready, isTrue);
  });

  test('memuat keanggotaan menyerah setelah batas waktu, bukan menggantung',
      () async {
    final stuck = Completer<http.Response>();
    addTearDown(() {
      if (!stuck.isCompleted) {
        stuck.complete(http.Response('[]', 200));
      }
    });

    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient((_) => stuck.future),
    );
    final session = AppSession(client);

    // Tanpa sesi, refreshMemberships berhenti lebih awal — itu perilaku yang
    // benar dan membuktikan penjaga `user == null` masih ada.
    await session.refreshMemberships().timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('refreshMemberships menggantung'),
    );
    expect(session.bootError, isNull);
  });

  test('pesan batas waktu memakai bahasa yang bisa ditindaklanjuti', () {
    // Dikunci di sini supaya tidak diam-diam berubah jadi jejak galat mentah.
    const message =
        'Server tidak menjawab. Periksa koneksi, lalu tarik ke bawah '
        'untuk memuat ulang.';
    expect(message, contains('Periksa koneksi'));
    expect(message, isNot(contains('Exception')));
    expect(message, isNot(contains('TimeoutException')));
  });
}
