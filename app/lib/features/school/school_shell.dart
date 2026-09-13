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
          tabBar: CupertinoTabBar(
            backgroundColor: Gl.surface.withValues(alpha: 0.96),
            activeColor: Gl.primary,
            inactiveColor: Gl.tertiary,
            border: const Border(top: BorderSide(color: Gl.line, width: 0)),
            iconSize: 24,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.tray),
                activeIcon: Icon(CupertinoIcons.tray_fill),
                label: 'Hari ini',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                activeIcon: Icon(CupertinoIcons.person_fill),
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
