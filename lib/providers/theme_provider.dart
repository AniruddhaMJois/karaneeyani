import 'package:flutter/material.dart';

enum AppTheme { midnightViolet, deepOcean, obsidian }

class ThemeProvider extends ChangeNotifier {
  AppTheme _currentTheme = AppTheme.midnightViolet;

  AppTheme get currentTheme => _currentTheme;

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppTheme.deepOcean:
        return _buildTheme(
          primary: const Color(0xFF0EA5E9),
          secondary: const Color(0xFF10B981),
          background: const Color(0xFF0F172A),
          surface: const Color(0xFF1E293B),
        );
      case AppTheme.obsidian:
        return _buildTheme(
          primary: const Color(0xFFF59E0B),
          secondary: const Color(0xFFEF4444),
          background: const Color(0xFF000000),
          surface: const Color(0xFF111111),
        );
      case AppTheme.midnightViolet:
      default:
        return _buildTheme(
          primary: const Color(0xFF8B5CF6),
          secondary: const Color(0xFF10B981),
          background: const Color(0xFF121212),
          surface: const Color(0xFF1E1E1E),
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
      dialogTheme: DialogTheme(
        backgroundColor: surface.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
