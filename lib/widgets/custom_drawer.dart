import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../screens/completed_tasks_screen.dart';
import '../screens/recycle_bin_screen.dart';
import '../screens/auth_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  accountName: Text(authService.user?.displayName?.isNotEmpty == true ? authService.user!.displayName! : 'Flow State Active', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  accountEmail: Text(authService.user?.email ?? 'Unknown User'),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.white),
                  title: const Text('Dashboard (Current Tasks)'),
                  onTap: () => Navigator.pop(context), // Already on dashboard
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  title: const Text('Completed Tasks'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CompletedTasksScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Recycle Bin'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                  },
                ),
                const Divider(color: Colors.white24),
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text('THEME ENGINE', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
                _buildThemeTile(context, themeProvider, 'Focus State', AppTheme.midnightViolet, const Color(0xFF00F0FF)),
                _buildThemeTile(context, themeProvider, 'Deep Ocean', AppTheme.deepOcean, const Color(0xFF0EA5E9)),
                _buildThemeTile(context, themeProvider, 'Obsidian', AppTheme.obsidian, const Color(0xFFF59E0B)),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context, ThemeProvider provider, String name, AppTheme theme, Color colorIndicator) {
    final isActive = provider.currentTheme == theme;
    return ListTile(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(shape: BoxShape.circle, color: colorIndicator),
      ),
      title: Text(name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      trailing: isActive ? Icon(Icons.check, color: Theme.of(context).colorScheme.secondary) : null,
      onTap: () => provider.setTheme(theme),
    );
  }
}
