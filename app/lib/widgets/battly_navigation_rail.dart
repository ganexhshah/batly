import 'package:flutter/material.dart';
import '../core/theme/battly_theme.dart';
import 'battly_nav_destinations.dart';

class BattlyNavigationRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BattlyNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final railTheme = Theme.of(context).navigationRailTheme;
    final navBarColor = context.battly.navBar;

    return Container(
      decoration: BoxDecoration(
        color: navBarColor,
        border: Border(
          right: BorderSide(color: context.battlyBorder, width: 1),
        ),
      ),
      child: NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: navBarColor,
        indicatorColor: railTheme.indicatorColor,
        selectedIconTheme: railTheme.selectedIconTheme,
        unselectedIconTheme: railTheme.unselectedIconTheme,
        selectedLabelTextStyle: railTheme.selectedLabelTextStyle,
        unselectedLabelTextStyle: railTheme.unselectedLabelTextStyle,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final item in battlyNavDestinations)
            NavigationRailDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.activeIcon),
              label: Text(item.label),
            ),
        ],
      ),
    );
  }
}
