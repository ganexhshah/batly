import 'package:flutter/material.dart';

/// Extra semantic colors not covered by [ColorScheme].
@immutable
class BattlyThemeColors extends ThemeExtension<BattlyThemeColors> {
  const BattlyThemeColors({
    required this.navBar,
    required this.profileBackground,
    required this.elevatedSurface,
  });

  final Color navBar;
  final Color profileBackground;
  final Color elevatedSurface;

  static const dark = BattlyThemeColors(
    navBar: Color(0xFF07080A),
    profileBackground: Color(0xFF07080A),
    elevatedSurface: Color(0xFF1A1D24),
  );

  static const light = BattlyThemeColors(
    navBar: Colors.white,
    profileBackground: Color(0xFFF4F5F8),
    elevatedSurface: Color(0xFFF0F1F5),
  );

  @override
  BattlyThemeColors copyWith({
    Color? navBar,
    Color? profileBackground,
    Color? elevatedSurface,
  }) {
    return BattlyThemeColors(
      navBar: navBar ?? this.navBar,
      profileBackground: profileBackground ?? this.profileBackground,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    );
  }

  @override
  BattlyThemeColors lerp(ThemeExtension<BattlyThemeColors>? other, double t) {
    if (other is! BattlyThemeColors) return this;
    return BattlyThemeColors(
      navBar: Color.lerp(navBar, other.navBar, t)!,
      profileBackground: Color.lerp(profileBackground, other.profileBackground, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
    );
  }
}

extension BattlyThemeContext on BuildContext {
  BattlyThemeColors get battly =>
      Theme.of(this).extension<BattlyThemeColors>() ?? BattlyThemeColors.dark;

  Color get battlyCard => Theme.of(this).colorScheme.surface;

  Color get battlyBorder => Theme.of(this).colorScheme.outline;

  Color get battlyMuted => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get battlyOnSurface => Theme.of(this).colorScheme.onSurface;

  Color get battlyScaffold => Theme.of(this).scaffoldBackgroundColor;
}
