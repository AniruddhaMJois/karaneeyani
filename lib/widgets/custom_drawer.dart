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
import '../screens/calendar_screen.dart';
import '../services/database_service.dart';
import '../screens/daily_roadmap_screen.dart';
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: const Color(0xFF121212).withOpacity(0.75), // Deep dark, transparent
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, authService, primaryColor),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          _buildSectionHeader('WORKFLOW'),
                          _buildNavItem(context, icon: Icons.dashboard_rounded, title: 'Dashboard', onTap: () => _navigate(context, const DailyRoadmapScreen()), color: Colors.white),
                          _buildNavItem(context, icon: Icons.event_note_rounded, title: 'Calendar', onTap: () => _navigate(context, const CalendarScreen()), color: Colors.purpleAccent),
                          _buildNavItem(context, icon: Icons.flag_rounded, title: 'Goals & Projects', onTap: () => _navigate(context, const GoalsScreen()), color: Colors.amberAccent),
                          _buildNavItem(context, icon: Icons.upcoming_rounded, title: 'Future Timeline', onTap: () => _navigate(context, const SortedTasksScreen()), color: Colors.blueAccent),
                          
                          const SizedBox(height: 24),
                          _buildSectionHeader('ARCHIVE'),
                          _buildNavItem(context, icon: Icons.check_circle_rounded, title: 'Completed Tasks', onTap: () => _navigate(context, const CompletedTasksScreen()), color: Colors.greenAccent),
                          _buildNavItem(context, icon: Icons.delete_rounded, title: 'Recycle Bin', onTap: () => _navigate(context, const RecycleBinScreen()), color: Colors.redAccent),
                          
                          const SizedBox(height: 24),
                          _buildSectionHeader('PREFERENCES'),
                          ThemeExpansionTile(themeProvider: themeProvider),
                          
                          const SizedBox(height: 24),
                          _buildSectionHeader('ACCOUNT'),
                          _buildNavItem(context, icon: Icons.logout_rounded, title: 'Logout', onTap: () => _handleLogout(context, authService), color: Colors.white54),
                          _buildNavItem(context, icon: Icons.warning_amber_rounded, title: 'Clear Database', onTap: () => _handleClearDatabase(context, authService), color: Colors.orange),
                          _buildNavItem(context, icon: Icons.person_remove_rounded, title: 'Delete Account', onTap: () => _handleDeleteAccount(context, authService), color: Colors.redAccent),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthService authService, Color primaryColor) {
    final userName = authService.user?.displayName?.isNotEmpty == true ? authService.user!.displayName! : 'Flow State Active';
    final userEmail = authService.user?.email ?? 'Unknown User';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.2),
            Colors.transparent,
          ],
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset('assets/icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  userName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.4), letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withOpacity(0.1),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close the drawer
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    await authService.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _handleClearDatabase(BuildContext context, AuthService authService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  }

  Future<void> _handleDeleteAccount(BuildContext context, AuthService authService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?', style: TextStyle(color: Colors.white)),
        content: const Text('This action is permanent and cannot be undone. All your tasks will be permanently deleted.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    
    if (confirm == true) {
      final error = await authService.deleteAccount();
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      } else if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }
}

class ThemeExpansionTile extends StatefulWidget {
  final ThemeProvider themeProvider;
  
  const ThemeExpansionTile({super.key, required this.themeProvider});

  @override
  State<ThemeExpansionTile> createState() => _ThemeExpansionTileState();
}

class _ThemeExpansionTileState extends State<ThemeExpansionTile> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Icon(Icons.palette_rounded, color: Colors.pinkAccent, size: 22),
        title: Text('Theme Engine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        childrenPadding: const EdgeInsets.only(left: 16, bottom: 8),
        children: [
          _buildThemeOption('Focus State', AppTheme.midnightViolet, const Color(0xFF00F0FF)),
          _buildThemeOption('Deep Ocean', AppTheme.deepOcean, const Color(0xFF0EA5E9)),
          _buildThemeOption('Obsidian', AppTheme.obsidian, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String name, AppTheme theme, Color colorIndicator) {
    final isActive = widget.themeProvider.currentTheme == theme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.themeProvider.setTheme(theme),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colorIndicator),
              ),
              const SizedBox(width: 16),
              Text(name, style: TextStyle(fontSize: 14, color: isActive ? Colors.white : Colors.white70, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
              const Spacer(),
              if (isActive) Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
