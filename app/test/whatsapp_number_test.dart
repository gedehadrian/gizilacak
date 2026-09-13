import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizilacak/config.dart';

void main() {
  // wa.me menolak nomor berawalan 0 atau yang memuat spasi dan tanda hubung.
  // Staf menuliskannya dalam berbagai bentuk, jadi normalisasinya dikunci di
  // sini — salah satu digit saja membuat tautannya membuka percakapan kosong
  // ke nomor yang salah, tanpa galat apa pun.
  // Nomor di bawah ini sengaja fiktif. Nomor sungguhan hanya ada di `.env`
  // yang tidak ikut masuk repositori.
  group('nomor WhatsApp dinormalkan untuk wa.me', () {
    test('awalan 0 diganti kode negara', () {
      dotenv.testLoad(fileInput: 'SUPPORT_WHATSAPP=081234567890');
      expect(AppConfig.supportWhatsappDigits, '6281234567890');
      expect(AppConfig.hasSupportWhatsapp, isTrue);
    });

    test('spasi, tanda hubung, dan tanda plus dibuang', () {
      dotenv.testLoad(fileInput: 'SUPPORT_WHATSAPP=+62 812-3456-7890');
      expect(AppConfig.supportWhatsappDigits, '6281234567890');
    });

    test('yang sudah berkode negara dibiarkan', () {
      dotenv.testLoad(fileInput: 'SUPPORT_WHATSAPP=6281234567890');
      expect(AppConfig.supportWhatsappDigits, '6281234567890');
    });

    test('kosong berarti baris WhatsApp tidak ditampilkan', () {
      dotenv.testLoad(fileInput: 'SUPPORT_WHATSAPP=');
      expect(AppConfig.supportWhatsappDigits, isEmpty);
      expect(AppConfig.hasSupportWhatsapp, isFalse);
    });

    test('nomor terlalu pendek dianggap belum diisi', () {
      dotenv.testLoad(fileInput: 'SUPPORT_WHATSAPP=0812');
      expect(AppConfig.hasSupportWhatsapp, isFalse);
    });
  });
}
