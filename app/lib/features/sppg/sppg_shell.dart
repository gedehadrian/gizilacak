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
          tabBar: CupertinoTabBar(
            backgroundColor: Gl.surface.withValues(alpha: 0.96),
            activeColor: Gl.primary,
            inactiveColor: Gl.tertiary,
            border: const Border(top: BorderSide(color: Gl.line, width: 0)),
            iconSize: 24,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.square_grid_2x2),
                activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                label: 'Hari ini',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.flame),
                activeIcon: Icon(CupertinoIcons.flame_fill),
                label: 'Produksi',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.cube_box),
                activeIcon: Icon(CupertinoIcons.cube_box_fill),
                label: 'Kiriman',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                activeIcon: Icon(CupertinoIcons.person_fill),
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
