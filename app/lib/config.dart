import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get webAppUrl =>
      dotenv.env['WEB_APP_URL'] ??
      const String.fromEnvironment('WEB_APP_URL', defaultValue: 'http://localhost:3000');

  /// Nomor WhatsApp untuk permintaan paket khusus. Disimpan di `.env` supaya
  /// tidak ikut masuk repositori dan bisa diganti tanpa menyentuh kode.
  static String get supportWhatsapp => dotenv.env['SUPPORT_WHATSAPP'] ?? '';

  /// Nomor dalam bentuk yang diterima wa.me: hanya angka, berawalan kode
  /// negara. `0822…` menjadi `62822…`.
  static String get supportWhatsappDigits {
    final digits = supportWhatsapp.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    return digits;
  }

  static bool get hasSupportWhatsapp => supportWhatsappDigits.length >= 9;

  static bool get isConfigured =>
      supabaseUrl.startsWith('http') && supabaseAnonKey.length > 20;
}
