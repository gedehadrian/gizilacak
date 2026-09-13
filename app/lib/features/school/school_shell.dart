import 'package:flutter/cupertino.dart';

import '../../theme/apple.dart';
import '../account/account_tab.dart';
import 'today_tab.dart';

class SchoolShell extends StatelessWidget {
  const SchoolShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gl.bg,
      child: GlPhone(
        child: CupertinoTabScaffold(
          tabBar: GlTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.inbox),
                activeIcon: Icon(LucideIcons.inbox),
                label: 'Hari ini',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.userRound),
                activeIcon: Icon(LucideIcons.userRound),
                label: 'Akun',
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return index == 0 ? const SchoolTodayTab() : const AccountTab();
          },
        ),
      ),
    );
  }
}
