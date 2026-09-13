import 'package:flutter/cupertino.dart';

import '../../theme/apple.dart';
import '../account/account_tab.dart';
import 'batches_tab.dart';
import 'deliveries_tab.dart';
import 'home_tab.dart';

class SppgShell extends StatelessWidget {
  const SppgShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gl.bg,
      child: GlPhone(
        child: CupertinoTabScaffold(
          tabBar: GlTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.layoutGrid),
                activeIcon: Icon(LucideIcons.layoutGrid),
                label: 'Hari ini',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.flame),
                activeIcon: Icon(LucideIcons.flame),
                label: 'Produksi',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.package),
                activeIcon: Icon(LucideIcons.package),
                label: 'Kiriman',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.userRound),
                activeIcon: Icon(LucideIcons.userRound),
                label: 'Akun',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return switch (index) {
              0 => const SppgHomeTab(),
              1 => const BatchesTab(),
              2 => const DeliveriesTab(),
              _ => const AccountTab(),
            };
          },
        ),
      ),
    );
  }
}
