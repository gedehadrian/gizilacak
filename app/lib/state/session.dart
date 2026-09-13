import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/api.dart';

enum OrgKind { tenant, school }

class OrgScope {
  const OrgScope({
    required this.kind,
    required this.id,
    required this.name,
    required this.code,
    required this.role,
  });

  final OrgKind kind;
  final String id;
  final String name;
  final String code;
  final String role;

  bool get isTenant => kind == OrgKind.tenant;
}

class AppSession extends ChangeNotifier {
  AppSession(this.client);

  final SupabaseClient client;
  late final Api api = Api(client);

  User? user;
  List<OrgScope> tenants = const [];
  List<OrgScope> schools = const [];
  OrgScope? current;
  bool ready = false;
  String? bootError;
  String? authError;
  bool recoveringPassword = false;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  Future<void>? _boot;
  final Set<String> _handledLinks = {};

  Future<void> handleAuthLink(Uri uri) async {
    if (!kIsWeb &&
        (uri.scheme != 'gizilacak' ||
            !{'reset-password', 'auth-callback'}.contains(uri.host))) {
      return;
    }
    if (!uri.queryParameters.containsKey('code') &&
        !uri.queryParameters.containsKey('error') &&
        !uri.queryParameters.containsKey('error_description') &&
        !uri.queryParameters.containsKey('access_token') &&
        !uri.fragment.contains('access_token=') &&
        !uri.fragment.contains('error=')) {
      return;
    }
    if (!_handledLinks.add(uri.toString())) return;
    try {
      await client.auth.getSessionFromUrl(uri).timeout(_networkTimeout);
      authError = null;
    } catch (_) {
      _handledLinks.remove(uri.toString());
      authError =
          'Tautan tidak berlaku atau gagal dibuka. Minta tautan baru dan buka di perangkat yang sama.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> boot() => _boot ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _bootSteps();
    } finally {
      // Apa pun yang terjadi di atas, layar boot harus berhenti berputar.
      ready = true;
      notifyListeners();
    }
  }

  Future<void> _bootSteps() async {
    _authSubscription = client.auth.onAuthStateChange.listen(
      (data) async {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          recoveringPassword = true;
          authError = null;
          user = data.session?.user;
          notifyListeners();
          return;
        }
        if (data.event == AuthChangeEvent.signedOut) recoveringPassword = false;
        user = data.session?.user;
        if (user == null) {
          tenants = const [];
          schools = const [];
          current = null;
          notifyListeners();
          return;
        }
        if (!recoveringPassword) await refreshMemberships();
      },
      onError: (Object error) {
        authError =
            'Sesi atau tautan tidak berlaku. Silakan masuk atau minta tautan baru.';
        notifyListeners();
      },
    );

    user = client.auth.currentUser;
    if (user != null) {
      await refreshMemberships();
    }
    if (kIsWeb) {
      await handleAuthLink(Uri.base);
    } else {
      final links = AppLinks();
      _linkSubscription = links.uriLinkStream.listen(
        (uri) => unawaited(handleAuthLink(uri)),
        onError: (Object error) {
          authError = 'Tautan gagal dibuka. Silakan minta tautan baru.';
          notifyListeners();
        },
      );
      try {
        final initial = await links.getInitialLink();
        if (initial != null) await handleAuthLink(initial);
      } catch (_) {
        authError = 'Tautan gagal dibuka. Silakan minta tautan baru.';
      }
    }
  }

  /// Batas tunggu satu panggilan ke server. Tanpa ini, koneksi yang menggantung
  /// — bukan gagal, tapi menggantung — membuat layar boot berputar selamanya
  /// karena tidak ada exception yang bisa ditangkap.
  static const _networkTimeout = Duration(seconds: 15);

  Future<void> refreshMemberships() async {
    if (user == null) return;
    try {
      final m = await api.memberships(user!.id).timeout(_networkTimeout);
      tenants = m.tenants;
      schools = m.schools;
      await _restoreScope();
      bootError = null;
    } on TimeoutException {
      bootError = 'Server tidak menjawab. Periksa koneksi, lalu tarik ke bawah '
          'untuk memuat ulang.';
    } catch (e) {
      bootError = e.toString();
    }
    notifyListeners();
  }

  Future<void> _restoreScope() async {
    final prefs = await SharedPreferences.getInstance();
    final kind = prefs.getString('gzl_kind');
    final id = prefs.getString('gzl_org');
    if (kind == null || id == null) {
      current = null;
      return;
    }
    final pool = kind == 'school' ? schools : tenants;
    current = pool.cast<OrgScope?>().firstWhere(
      (o) => o?.id == id,
      orElse: () => null,
    );
  }

  Future<void> select(OrgScope org) async {
    current = org;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gzl_kind', org.isTenant ? 'tenant' : 'school');
    await prefs.setString('gzl_org', org.id);
    notifyListeners();
  }

  Future<void> clearOrg() async {
    current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gzl_kind');
    await prefs.remove('gzl_org');
    notifyListeners();
  }

  Future<void> signOut() async {
    await clearOrg();
    await client.auth.signOut();
  }
}

class SessionScope extends InheritedNotifier<AppSession> {
  const SessionScope({
    super.key,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);

  static AppSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope missing');
    return scope!.notifier!;
  }
}
