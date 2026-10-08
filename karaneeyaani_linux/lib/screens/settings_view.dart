import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';

class SettingsView extends StatefulWidget {
  final DatabaseService dbService;

  const SettingsView({super.key, required this.dbService});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final pinAuthService = context.watch<PinAuthService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: Colors.white.withOpacity(0.02),
          child: Row(
            children: [
              Icon(Icons.settings_suggest_rounded, color: colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Settings & Preferences',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),

        // Scrollable settings body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // 1. Appearance / Theme Section
              _buildSectionHeader(Icons.palette_outlined, 'APPEARANCE & THEME', colorScheme),
              const SizedBox(height: 12),
              _buildThemeGrid(context, themeProvider, colorScheme),
              const SizedBox(height: 28),

              // 2. Security & Authentication Section
              _buildSectionHeader(Icons.security_rounded, 'SECURITY & AUTHENTICATION', colorScheme),
              const SizedBox(height: 12),
              _buildSecuritySection(context, pinAuthService, colorScheme),
              const SizedBox(height: 28),

              // 3. Data & Storage Section
              _buildSectionHeader(Icons.storage_rounded, 'DATA & STORAGE', colorScheme),
              const SizedBox(height: 12),
              _buildDataSection(context, colorScheme),
              const SizedBox(height: 28),

              // 4. About App Section
              _buildSectionHeader(Icons.info_outline_rounded, 'ABOUT KARANEEYAANI', colorScheme),
              const SizedBox(height: 12),
              _buildAboutSection(colorScheme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeGrid(BuildContext context, ThemeProvider themeProvider, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Application Theme',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dynamic neon glassmorphism palettes customized for Linux desktop.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppTheme.values.map((theme) {
              final isSelected = themeProvider.currentTheme == theme;
              final previewColors = _getThemePreviewColors(theme);

              return InkWell(
                onTap: () => themeProvider.setTheme(theme),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 170,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? previewColors[0].withOpacity(0.2) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? previewColors[0] : Colors.white10,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [previewColors[0], previewColors[1]],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getThemeTitle(theme),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, size: 16, color: previewColors[0]),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Color> _getThemePreviewColors(AppTheme theme) {
    switch (theme) {
      case AppTheme.midnightViolet:
        return [const Color(0xFF9D4EDD), const Color(0xFF00F5D4)];
      case AppTheme.deepOcean:
        return [const Color(0xFF00B4D8), const Color(0xFF0077B6)];
      case AppTheme.obsidian:
        return [const Color(0xFFFFD166), const Color(0xFFF77F00)];
      case AppTheme.emeraldFlow:
        return [const Color(0xFF2ECC71), const Color(0xFF27AE60)];
      case AppTheme.solarFlare:
        return [const Color(0xFFFF6B6B), const Color(0xFFFFA502)];
      case AppTheme.arcticIce:
        return [const Color(0xFF48CAE4), const Color(0xFFADE8F4)];
      case AppTheme.roseNebula:
        return [const Color(0xFFFF758F), const Color(0xFFFF4D6D)];
    }
  }

  String _getThemeTitle(AppTheme theme) {
    switch (theme) {
      case AppTheme.midnightViolet:
        return 'Cyberpunk';
      case AppTheme.deepOcean:
        return 'Deep Ocean';
      case AppTheme.obsidian:
        return 'Obsidian';
      case AppTheme.emeraldFlow:
        return 'Emerald';
      case AppTheme.solarFlare:
        return 'Solar Flare';
      case AppTheme.arcticIce:
        return 'Arctic Ice';
      case AppTheme.roseNebula:
        return 'Rose Nebula';
    }
  }

  Widget _buildSecuritySection(
    BuildContext context,
    PinAuthService pinAuthService,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          // Biometric Toggle (Explicitly requested by user)
          SwitchListTile(
            value: pinAuthService.isBiometricsEnabled,
            activeColor: colorScheme.primary,
            title: const Text('Biometric Authentication', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Use biometric authentication on startup if supported, falling back to 6-digit PIN.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            secondary: Icon(Icons.fingerprint_rounded, color: colorScheme.primary),
            onChanged: (val) {
              pinAuthService.setBiometricsEnabled(val);
            },
          ),
          const Divider(color: Colors.white10, height: 1),

          // Change PIN
          ListTile(
            leading: Icon(Icons.pin_rounded, color: colorScheme.primary),
            title: const Text('Change 6-Digit PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text('Update the master security PIN used to unlock Karaneeyaani.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () => _showChangePinDialog(context, pinAuthService),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Lock App Now
          ListTile(
            leading: const Icon(Icons.lock_rounded, color: Colors.amberAccent),
            title: const Text('Lock Application Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text('Instantly lock the workspace and prompt for PIN verification.', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () {
              pinAuthService.lock();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                '100% Offline & Private',
                style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'All your tasks, projects, schedules, and security credentials are encrypted and stored locally on your Linux machine using atomic JSON files. Zero telemetry or external network calls.',
            style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmResetDatabase(context),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Reset All Workspace Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.task_alt_rounded, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Karaneeyaani for Linux',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Version 1.0.0 • Native Linux Desktop Edition',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                'OM NAMO BHAGAVATE RUDRAYA',
                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, PinAuthService pinAuthService) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String error = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Change 6-Digit PIN', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Current 6-Digit PIN',
                      labelStyle: TextStyle(color: Colors.white60),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'New 6-Digit PIN',
                      labelStyle: TextStyle(color: Colors.white60),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Confirm New 6-Digit PIN',
                      labelStyle: TextStyle(color: Colors.white60),
                      counterText: '',
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newPinController.text.length != 6) {
                    setDialogState(() => error = 'New PIN must be exactly 6 digits.');
                    return;
                  }
                  if (newPinController.text != confirmPinController.text) {
                    setDialogState(() => error = 'New PINs do not match.');
                    return;
                  }
                  final success = await pinAuthService.changePin(oldPinController.text, newPinController.text);
                  if (success) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('6-Digit PIN updated successfully!')),
                    );
                  } else {
                    setDialogState(() => error = 'Incorrect current PIN.');
                  }
                },
                child: const Text('Save PIN'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmResetDatabase(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset All Workspace Data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all active tasks, goals, completed items, and trash. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.dbService.clearAllTasks();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workspace data has been reset.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reset Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
