import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../screens/completed_tasks_screen.dart';
import '../screens/recycle_bin_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/sorted_tasks_screen.dart';
import '../screens/goals_screen.dart';
import '../services/database_service.dart';

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
                  leading: const Icon(Icons.calendar_month, color: Colors.blueAccent),
                  title: const Text('Calendar View (Sorted)'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SortedTasksScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.amberAccent),
                  title: const Text('Goals & Projects'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()));
                  },
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
                ExpansionTile(
                  leading: const Icon(Icons.palette, color: Colors.purpleAccent),
                  title: const Text('Theme Engine', style: TextStyle(fontWeight: FontWeight.bold)),
                  childrenPadding: const EdgeInsets.only(left: 16),
                  children: [
                    _buildThemeTile(context, themeProvider, 'Focus State', AppTheme.midnightViolet, const Color(0xFF00F0FF)),
                    _buildThemeTile(context, themeProvider, 'Deep Ocean', AppTheme.deepOcean, const Color(0xFF0EA5E9)),
                    _buildThemeTile(context, themeProvider, 'Obsidian', AppTheme.obsidian, const Color(0xFFF59E0B)),
                  ],
                ),
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
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: const Text('Clear All Tasks', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF2A2A2A),
                        title: const Text('Clear All Tasks?', style: TextStyle(color: Colors.white)),
                        content: const Text('This will permanently delete ALL tasks in your database. Are you sure?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear', style: TextStyle(color: Colors.orange))),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final dbService = DatabaseService(userId: authService.user!.uid);
                      await dbService.clearAllTasks();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database cleared successfully.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                        Navigator.pop(context);
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF2A2A2A),
                        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
                        content: const Text('This action is permanent and cannot be undone. All your tasks will be permanently deleted.', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      final error = await authService.deleteAccount();
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                      } else if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                          (route) => false,
                        );
                      }
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
