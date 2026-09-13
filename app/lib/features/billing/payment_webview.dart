import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/apple.dart';

/// Membuka halaman pembayaran Midtrans.
///
/// Di Android dan iOS halaman dibuka di dalam app lewat webview. Flutter web
/// tidak punya webview, jadi di sana tautannya dibuka di tab baru — perilaku
/// yang sama, jalur berbeda.
Future<void> openPayment(BuildContext context, String url) async {
  if (kIsWeb) {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      await showGlError(context, 'Tidak bisa membuka halaman pembayaran.');
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute(builder: (_) => PaymentWebView(url: url)),
  );
}

class PaymentWebView extends StatefulWidget {
  const PaymentWebView({super.key, required this.url});

  final String url;

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController controller;
  int progress = 0;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Gl.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Gl.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GlTopBar(
              title: 'Pembayaran',
              subtitle: 'Midtrans',
              onBack: () => Navigator.maybePop(context),
            ),
            if (progress < 100)
              SizedBox(
                height: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress / 100,
                    child: const ColoredBox(color: Gl.primary),
                  ),
                ),
              ),
            Expanded(child: WebViewWidget(controller: controller)),
          ],
        ),
      ),
    );
  }
}
