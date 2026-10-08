import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  midnightViolet,
  deepOcean,
  obsidian,
  emeraldFlow,
  solarFlare,
  arcticIce,
  roseNebula,
}

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'selected_app_theme';
  AppTheme _currentTheme = AppTheme.midnightViolet;

  AppTheme get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_prefKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < AppTheme.values.length) {
        _currentTheme = AppTheme.values[themeIndex];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, theme.index);
    } catch (_) {}
  }

  String get themeName {
    switch (_currentTheme) {
      case AppTheme.midnightViolet:
        return 'Neon Cyberpunk';
      case AppTheme.deepOcean:
        return 'Deep Ocean';
      case AppTheme.obsidian:
        return 'Golden Obsidian';
      case AppTheme.emeraldFlow:
        return 'Emerald Flow';
      case AppTheme.solarFlare:
        return 'Solar Flare';
      case AppTheme.arcticIce:
        return 'Arctic Ice';
      case AppTheme.roseNebula:
        return 'Rose Nebula';
    }
  }

  Color get primaryColor {
    switch (_currentTheme) {
      case AppTheme.midnightViolet:
        return const Color(0xFF00F0FF);
      case AppTheme.deepOcean:
        return const Color(0xFF0EA5E9);
      case AppTheme.obsidian:
        return const Color(0xFFF59E0B);
      case AppTheme.emeraldFlow:
        return const Color(0xFF10B981);
      case AppTheme.solarFlare:
        return const Color(0xFFFF5722);
      case AppTheme.arcticIce:
        return const Color(0xFF38BDF8);
      case AppTheme.roseNebula:
        return const Color(0xFFEC4899);
    }
  }

  Color get secondaryColor {
    switch (_currentTheme) {
      case AppTheme.midnightViolet:
        return const Color(0xFF39FF14);
      case AppTheme.deepOcean:
        return const Color(0xFF10B981);
      case AppTheme.obsidian:
        return const Color(0xFFEF4444);
      case AppTheme.emeraldFlow:
        return const Color(0xFF34D399);
      case AppTheme.solarFlare:
        return const Color(0xFFFF9800);
      case AppTheme.arcticIce:
        return const Color(0xFF67E8F9);
      case AppTheme.roseNebula:
        return const Color(0xFFF472B6);
    }
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.deepOcean:
        return _buildTheme(
          primary: const Color(0xFF0EA5E9),
          secondary: const Color(0xFF10B981),
          background: const Color(0xFF0B132B),
          surface: const Color(0xFF1C2541),
        );
      case AppTheme.obsidian:
        return _buildTheme(
          primary: const Color(0xFFF59E0B),
          secondary: const Color(0xFFEF4444),
          background: const Color(0xFF000000),
          surface: const Color(0xFF121212),
        );
      case AppTheme.emeraldFlow:
        return _buildTheme(
          primary: const Color(0xFF10B981),
          secondary: const Color(0xFF34D399),
          background: const Color(0xFF061A14),
          surface: const Color(0xFF0E2E24),
        );
      case AppTheme.solarFlare:
        return _buildTheme(
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFFFF9800),
          background: const Color(0xFF1A0A05),
          surface: const Color(0xFF2E120A),
        );
      case AppTheme.arcticIce:
        return _buildTheme(
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF67E8F9),
          background: const Color(0xFF07131E),
          surface: const Color(0xFF0E2235),
        );
      case AppTheme.roseNebula:
        return _buildTheme(
          primary: const Color(0xFFEC4899),
          secondary: const Color(0xFFF472B6),
          background: const Color(0xFF190614),
          surface: const Color(0xFF2F0F27),
        );
      case AppTheme.midnightViolet:
        return _buildTheme(
          primary: const Color(0xFF00F0FF),
          secondary: const Color(0xFF39FF14),
          background: const Color(0xFF050505),
          surface: const Color(0xFF121212),
        );
    }
  }

  ThemeData _buildTheme({
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
  }) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
