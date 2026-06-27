import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';
import 'battly_nav_destinations.dart';

class BattlyNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BattlyNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final navBarColor = context.battly.navBar;

    return Container(
      decoration: BoxDecoration(color: navBarColor),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: navBarColor,
        selectedItemColor: navTheme.selectedItemColor,
        unselectedItemColor: navTheme.unselectedItemColor,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final item in battlyNavDestinations)
            BottomNavigationBarItem(
              icon: Icon(item.icon, semanticLabel: '${item.label} tab'),
              activeIcon: Icon(item.activeIcon, semanticLabel: '${item.label} tab, selected'),
              label: item.label,
              tooltip: item.label,
            ),
        ],
      ),
    );
  }
}
