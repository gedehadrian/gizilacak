import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/app.dart';
import 'package:gizilacak/data/api.dart';
import 'package:gizilacak/features/auth/password_page.dart';
import 'package:gizilacak/state/session.dart';
import 'package:gizilacak/features/reports/reports_page.dart'
    show neutralizeCsv, toCsv;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = '00000000-0000-4000-8000-000000000001';
  final user = {
    'id': uid,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'test@example.invalid',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-09-01T00:00:00Z',
  };
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': uid, 'exp': 4102444800})))}.signature';
  final recoveryUri = Uri.parse(
    'gizilacak://reset-password#access_token=$token&refresh_token=fixture&expires_in=3600&token_type=bearer&type=recovery',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/messages'),
          (_) async => null,
        );
  });

  Future<SupabaseClient> clientFor(
    Future<http.Response> Function(http.Request) handler,
  ) async => (await TestWidgetsFlutterBinding.instance.runAsync(() async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: _MemoryStorage(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return client;
  }))!;

  test(
    'CSV neutralizes formulas, whitespace prefixes and preserves quotes',
    () {
      for (final value in [
        '=1+1',
        '+1',
        '-1',
        '@SUM(A1)',
        '\t=1+1',
        '\r=1+1',
        '\n=1+1',
        '  =1+1',
      ]) {
        expect(neutralizeCsv(value), startsWith("'"));
      }
      expect(
        toCsv([
          ['a,b', 'say "hi"'],
        ]),
        '"a,b","say ""hi"""',
      );
    },
  );

  testWidgets('PKCE code exchange emits recovery once in a running app', (
    tester,
  ) async {
    var exchanges = 0;
    final client = await clientFor((request) async {
      if (request.url.path.endsWith('/token')) {
        exchanges++;
        expect((jsonDecode(request.body) as Map)['code_verifier'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'fixture',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': user,
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final session = AppSession(client);
    await session.boot();
    await client.auth.resetPasswordForEmail(
      'test@example.invalid',
      redirectTo: 'gizilacak://reset-password',
    );
    final uri = Uri.parse('gizilacak://reset-password?code=test-code');
    await session.handleAuthLink(uri);
    await tester.pump();
    expect(session.recoveringPassword, isTrue);
    await session.handleAuthLink(uri);
    expect(exchanges, 1);
    session.dispose();
    await tester.runAsync(client.dispose);
  });

  testWidgets(
    'cold-start recovery takes priority and returns to login after update',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.llfbandit.app_links/messages'),
            (call) async =>
                call.method == 'getInitialLink' ? recoveryUri.toString() : null,
          );
      String? saved;
      final client = await clientFor((request) async {
        if (request.url.path.endsWith('/user')) {
          if (request.method == 'PUT') {
            saved = (jsonDecode(request.body) as Map)['password'] as String;
          }
          return http.Response(jsonEncode(user), 200);
        }
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200);
        }
        return http.Response('[]', 200);
      });
      final session = AppSession(client);
      await tester.pumpWidget(GiziApp(session: session));
      await tester.pumpAndSettle();
      expect(find.text('Ganti kata sandi'), findsOneWidget);
      expect(session.recoveringPassword, isTrue);
      await tester.enterText(
        find.byType(EditableText).at(0),
        'new-password-123',
      );
      await tester.enterText(
        find.byType(EditableText).at(1),
        'different-password',
      );
      await tester.tap(find.text('Simpan kata sandi'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Konfirmasi kata sandi tidak cocok.'), findsOneWidget);
      await tester.enterText(
        find.byType(EditableText).at(1),
        'new-password-123',
      );
      await tester.tap(find.text('Simpan kata sandi'));
      await tester.pumpAndSettle();
      expect(saved, 'new-password-123');
      expect(session.recoveringPassword, isFalse);
      expect(find.text('Lupa kata sandi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      await tester.runAsync(client.dispose);
    },
  );

  testWidgets('expired and foreign links never grant recovery access', (
    tester,
  ) async {
    var calls = 0;
    final client = await clientFor((_) async {
      calls++;
      return http.Response('{}', 400);
    });
    final session = AppSession(client);
    await session.boot();
    await session.handleAuthLink(
      Uri.parse('other://reset-password#access_token=x'),
    );
    expect(calls, 0);
    await session.handleAuthLink(
      Uri.parse(
        'gizilacak://reset-password#error=access_denied&error_description=Expired',
      ),
    );
    expect(session.recoveringPassword, isFalse);
    expect(session.authError, isNotNull);
    session.dispose();
    await tester.runAsync(client.dispose);
  });

  testWidgets('reset request validates email and uses the native redirect', (
    tester,
  ) async {
    Uri? requested;
    final client = await clientFor((request) async {
      requested = request.url;
      return http.Response('{}', 200);
    });
    final session = AppSession(client);
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: const CupertinoApp(home: PasswordPage()),
      ),
    );
    await tester.tap(find.text('Kirim tautan pemulihan'));
    await tester.pumpAndSettle();
    expect(requested, isNull);
    await tester.enterText(
      find.byType(EditableText),
      'test@example.invalid',
    );
    await tester.tap(find.text('Kirim tautan pemulihan'));
    await tester.pumpAndSettle();
    expect(
      requested?.queryParameters['redirect_to'],
      'gizilacak://reset-password',
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    await tester.runAsync(client.dispose);
  });

  testWidgets(
    'version collision retries without overwriting and always uses one month',
    (tester) async {
      var attempts = 0;
      final inserts = <Map<String, dynamic>>[];
      final client = await clientFor((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'version': attempts + 2}), 200);
        }
        inserts.add(jsonDecode(request.body) as Map<String, dynamic>);
        attempts++;
        return attempts == 1
            ? http.Response('{"code":"23505","message":"duplicate"}', 409)
            : http.Response('', 201);
      });
      await Api(client).createPlanVersion(
        planId: 'plan',
        priceRp: 120000,
        staffLimit: 2,
        schoolLimit: 3,
        deliveryLimit: 4,
      );
      expect(inserts.map((r) => r['version']), [3, 4]);
      expect(
        inserts.every(
          (r) => r['period_months'] == 1 && !r.containsKey('published_at'),
        ),
        isTrue,
      );
      await tester.runAsync(client.dispose);
    },
  );

  testWidgets('publish reports an RLS-filtered or already published row', (
    tester,
  ) async {
    final client = await clientFor((_) async => http.Response('null', 200));
    await expectLater(
      Api(client).publishPlanVersion('missing'),
      throwsA(isA<ApiException>()),
    );
    await tester.runAsync(client.dispose);
  });
}

class _MemoryStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

