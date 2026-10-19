import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/pin_auth_service.dart';
import '../screens/completed_tasks_screen.dart';
import '../screens/recycle_bin_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/sorted_tasks_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/calendar_screen.dart';
import '../services/database_service.dart';
import '../screens/daily_roadmap_screen.dart';
import '../screens/settings_screen.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final pinAuth = Provider.of<PinAuthService>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: const Color(0xFF121212).withValues(alpha: 0.75),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, authService, pinAuth, primaryColor),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          _buildSectionHeader('ARENA & WORKFLOW'),
                          _buildNavItem(context, icon: Icons.dashboard_rounded, title: "Today's Arena", onTap: () => _navigate(context, const DailyRoadmapScreen()), color: Colors.white),
                          _buildNavItem(context, icon: Icons.event_note_rounded, title: 'Calendar', onTap: () => _navigate(context, const CalendarScreen()), color: Colors.purpleAccent),
                          _buildNavItem(context, icon: Icons.flag_rounded, title: 'Goals Arena', onTap: () => _navigate(context, const GoalsScreen()), color: Colors.amberAccent),
                          _buildNavItem(context, icon: Icons.upcoming_rounded, title: 'Future Timeline', onTap: () => _navigate(context, const SortedTasksScreen()), color: Colors.blueAccent),

                          const SizedBox(height: 24),
                          _buildSectionHeader('ARCHIVE'),
                          _buildNavItem(context, icon: Icons.check_circle_rounded, title: 'Completed Tasks', onTap: () => _navigate(context, const CompletedTasksScreen()), color: Colors.greenAccent),
                          _buildNavItem(context, icon: Icons.delete_rounded, title: 'Recycle Bin', onTap: () => _navigate(context, const RecycleBinScreen()), color: Colors.redAccent),

                          const SizedBox(height: 24),
                          _buildSectionHeader('PREFERENCES & SETTINGS'),
                          ThemeExpansionTile(themeProvider: themeProvider),
                          _buildNavItem(context, icon: Icons.settings_rounded, title: 'Daily Routine Planner', onTap: () => _navigate(context, const SettingsScreen()), color: Colors.cyanAccent),

                          const SizedBox(height: 24),
                          _buildSectionHeader('SECURITY & ACCOUNT'),
                          _buildBiometricToggleItem(context, pinAuth),
                          _buildNavItem(context, icon: Icons.switch_account_rounded, title: 'Sign Out / Switch Account', onTap: () => _handleSwitchAccount(context, authService, pinAuth), color: Colors.lightBlueAccent),
                          _buildNavItem(context, icon: Icons.lock_outline_rounded, title: 'Lock App', onTap: () => _handleLockApp(context), color: Colors.white70),
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

  Widget _buildHeader(BuildContext context, AuthService authService, PinAuthService pinAuth, Color primaryColor) {
    final userName = pinAuth.username?.isNotEmpty == true
        ? '@${pinAuth.username}'
        : (authService.user?.displayName?.isNotEmpty == true ? authService.user!.displayName! : 'Flow State Active');
    final userEmail = authService.user?.email ?? 'Offline Security Vault';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
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
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5),
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
          hoverColor: color.withValues(alpha: 0.1),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.1),
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
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricToggleItem(BuildContext context, PinAuthService pinAuth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.fingerprint_rounded, size: 22, color: Colors.tealAccent),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Biometric Unlock',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              Switch.adaptive(
                value: pinAuth.isBiometricsEnabled,
                activeTrackColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) async {
                  if (val) {
                    final supported = await pinAuth.isBiometricsSupported();
                    if (!supported) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Biometrics not supported on this device.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }
                    final authenticated = await pinAuth.authenticateWithBiometrics(
                      reason: 'Authenticate to enable biometric unlock',
                    );
                    if (authenticated) {
                      await pinAuth.setBiometricsEnabled(true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biometric authentication enabled!'), backgroundColor: Colors.green),
                        );
                      }
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric verification cancelled.'), backgroundColor: Colors.orange),
                      );
                    }
                  } else {
                    await pinAuth.setBiometricsEnabled(false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric unlock disabled. PIN will be used.'), backgroundColor: Colors.orange),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
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

  void _handleLockApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _handleSwitchAccount(BuildContext context, AuthService authService, PinAuthService pinAuth) async {
    final userController = TextEditingController();
    final pinController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.switch_account_rounded, color: Colors.lightBlueAccent),
            SizedBox(width: 10),
            Text('Switch Account', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Username and 6-digit PIN to authenticate against Supabase.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.person, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '6-digit PIN',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.pin, color: Colors.white54),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            child: const Text('Sign In & Switch', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final u = userController.text.trim();
      final p = pinController.text.trim();

      final error = await authService.switchAccount(
        username: u,
        pin: p,
        pinAuth: pinAuth,
      );

      if (!context.mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched account to @$u'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DailyRoadmapScreen()),
          (route) => false,
        );
      }
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
      final user = authService.user;
      final uid = user?.uid ?? 'local_user';
      final dbService = DatabaseService(userId: uid);
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

    if (confirm == true && context.mounted) {
      final pinAuth = Provider.of<PinAuthService>(context, listen: false);
      final error = await authService.deleteAccount();
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      } else if (context.mounted) {
        await pinAuth.resetAll();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (route) => false,
          );
        }
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
        title: Text('Theme Engine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
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
