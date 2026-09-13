import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/data/api.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Klien yang menolak permintaan jaringan apa pun. Seluruh pemeriksaan di bawah
/// harus gagal sebelum menyentuh jaringan; kalau sampai ada yang lolos ke sini,
/// test akan gagal dengan pesan yang jelas.
SupabaseClient _offlineClient() {
  return SupabaseClient(
    'https://example.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      fail('Tidak boleh ada permintaan jaringan: ${request.url}');
    }),
  );
}

void main() {
  late Api api;

  setUp(() => api = Api(_offlineClient()));

  group('Muatan kiriman diperiksa sebelum dikirim ke server', () {
    test('menolak kiriman tanpa satu pun komponen', () async {
      expect(
        () => api.createDelivery(tenantId: 't', schoolId: 's', items: const []),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('minimal satu komponen'),
          ),
        ),
      );
    });

    test('menolak porsi nol atau negatif, dan menyebut nama komponennya', () async {
      expect(
        () => api.createDelivery(
          tenantId: 't',
          schoolId: 's',
          items: const [
            DeliveryLine(componentId: 'c1', portions: 0, label: 'Nasi putih'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Nasi putih'), contains('lebih dari 0')),
          ),
        ),
      );
    });

    test('menolak komponen yang sama dua kali dalam satu kiriman', () async {
      // `delivery_items` punya unique (delivery_id, batch_component_id), jadi
      // duplikat ditangkap lebih awal dengan pesan yang bisa ditindaklanjuti.
      expect(
        () => api.createDelivery(
          tenantId: 't',
          schoolId: 's',
          items: const [
            DeliveryLine(componentId: 'c1', portions: 60, label: 'Ayam kecap'),
            DeliveryLine(componentId: 'c1', portions: 60, label: 'Ayam kecap'),
          ],
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Ayam kecap'), contains('dua kali')),
          ),
        ),
      );
    });

    test('beberapa komponen berbeda diterima sampai tahap jaringan', () async {
      // Lolos validasi lokal, lalu gagal di MockClient — itu bukti bahwa tiga
      // komponen berbeda dalam satu kiriman memang diteruskan ke server.
      expect(
        () => api.createDelivery(
          tenantId: 't',
          schoolId: 's',
          items: const [
            DeliveryLine(componentId: 'c1', portions: 120, label: 'Nasi'),
            DeliveryLine(componentId: 'c2', portions: 60, label: 'Ayam kecap'),
            DeliveryLine(componentId: 'c3', portions: 60, label: 'Tumis buncis'),
          ],
        ),
        throwsA(isNot(isA<ApiException>())),
      );
    });
  });
}
