import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/battly_theme.dart';
import 'local_cache.dart';

/// App-wide dark / light theme preference (persisted locally).
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const _storageKey = 'settings_dark_mode';

  bool _isDarkMode = true;
  bool _loaded = false;

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _loaded;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final stored = await LocalCache.read(_storageKey);
    if (stored != null) {
      _isDarkMode = stored == 'true';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    await LocalCache.write(_storageKey, enabled.toString());
    notifyListeners();
  }

  Future<void> toggle() => setDarkMode(!_isDarkMode);

  static ThemeData buildDarkTheme(TextTheme textTheme) {
    const primary = Color(0xFFFF6B00);
    const scheme = ColorScheme.dark(
      primary: primary,
      secondary: Color(0xFFFFD700),
      surface: Color(0xFF15181E),
      surfaceContainerHighest: Color(0xFF1A1D24),
      outline: Color(0xFF2B2F3A),
      onPrimary: Colors.white,
      onSecondary: Color(0xFF0F1115),
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFFA0A0A0),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      colorScheme: scheme,
      textTheme: textTheme,
      useMaterial3: true,
      extensions: const [BattlyThemeColors.dark],
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F1115),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF07080A),
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFFA0A0A0),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF07080A),
        indicatorColor: primary.withValues(alpha: 0.15),
        selectedIconTheme: const IconThemeData(color: primary, size: 26),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFFA0A0A0),
          size: 24,
        ),
        selectedLabelTextStyle: GoogleFonts.poppins(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: GoogleFonts.poppins(
          color: const Color(0xFFA0A0A0),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF2B2F3A)),
        ),
      ),
      dividerColor: const Color(0xFF2B2F3A),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surface,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0F1115),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.2);
          }
          return const Color(0xFF2B2F3A);
        }),
      ),
    );
  }

  static ThemeData buildLightTheme(TextTheme textTheme) {
    const primary = Color(0xFFFF6B00);
    const scheme = ColorScheme.light(
      primary: primary,
      secondary: Color(0xFFFFD700),
      surface: Colors.white,
      surfaceContainerHighest: Color(0xFFF0F1F5),
      outline: Color(0xFFE0E3EA),
      onPrimary: Colors.white,
      onSecondary: Color(0xFF1A1D24),
      onSurface: Color(0xFF1A1D24),
      onSurfaceVariant: Color(0xFF6B6F7A),
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F5F8),
      colorScheme: scheme,
      textTheme: textTheme,
      useMaterial3: true,
      extensions: const [BattlyThemeColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF4F5F8),
        foregroundColor: const Color(0xFF1A1D24),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF1A1D24),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1D24)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: Color(0xFF6B6F7A),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.12),
        selectedIconTheme: const IconThemeData(color: primary, size: 26),
        unselectedIconTheme: const IconThemeData(
          color: Color(0xFF6B6F7A),
          size: 24,
        ),
        selectedLabelTextStyle: GoogleFonts.poppins(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF6B6F7A),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE0E3EA)),
        ),
      ),
      dividerColor: const Color(0xFFE0E3EA),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surface,
        contentTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF1A1D24),
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.grey[400];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: 0.2);
          }
          return const Color(0xFFE0E3EA);
        }),
      ),
    );
  }
}
