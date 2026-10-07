import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/pin_auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingBiometrics = false;

  Future<void> _toggleBiometrics(bool value) async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);

    if (value) {
      setState(() => _isCheckingBiometrics = true);
      final isSupported = await pinAuth.isBiometricsSupported();

      if (!isSupported) {
        if (mounted) {
          setState(() => _isCheckingBiometrics = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometrics are not supported or enrolled on this device.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final authenticated = await pinAuth.authenticateWithBiometrics(
        reason: 'Authenticate to enable biometric unlock',
      );

      if (mounted) {
        setState(() => _isCheckingBiometrics = false);
        if (authenticated) {
          await pinAuth.setBiometricsEnabled(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric authentication enabled.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric verification was cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      await pinAuth.setBiometricsEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled. PIN unlock will be used.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showChangePinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ChangePinBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final pinAuth = Provider.of<PinAuthService>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Section: Security
          _buildSectionHeader('SECURITY'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                // Biometric Toggle Tile
                SwitchListTile.adaptive(
                  value: pinAuth.isBiometricsEnabled,
                  onChanged: _isCheckingBiometrics ? null : _toggleBiometrics,
                  activeColor: theme.colorScheme.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Biometric Authentication',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  subtitle: Text(
                    pinAuth.isBiometricsEnabled
                        ? 'Fingerprint / Face ID is active for quick unlock'
                        : 'Enable Fingerprint / Face ID for faster login',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1, indent: 56),
                // Change PIN
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_rounded, color: Colors.amber, size: 24),
                  ),
                  title: const Text(
                    'Change 6-Digit PIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Update your app lock passcode',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  onTap: () => _showChangePinSheet(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: Appearance
          _buildSectionHeader('APPEARANCE'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                _buildThemeTile('Focus State', AppTheme.midnightViolet, const Color(0xFF00F0FF), themeProvider),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1, indent: 56),
                _buildThemeTile('Deep Ocean', AppTheme.deepOcean, const Color(0xFF0EA5E9), themeProvider),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1, indent: 56),
                _buildThemeTile('Obsidian', AppTheme.obsidian, const Color(0xFFF59E0B), themeProvider),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: About
          _buildSectionHeader('ABOUT'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/icon.png', width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Karaneeyaani',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Focused Task Flow • Version 1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    String name,
    AppTheme theme,
    Color indicator,
    ThemeProvider themeProvider,
  ) {
    final isSelected = themeProvider.currentTheme == theme;
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: indicator,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => themeProvider.setTheme(theme),
    );
  }
}

class _ChangePinBottomSheet extends StatefulWidget {
  const _ChangePinBottomSheet();

  @override
  State<_ChangePinBottomSheet> createState() => _ChangePinBottomSheetState();
}

class _ChangePinBottomSheetState extends State<_ChangePinBottomSheet> {
  int _step = 1; // 1: Verify current PIN, 2: Enter new PIN, 3: Confirm new PIN
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _error;

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_step == 1 && _currentPin.length < 6) {
        _currentPin += digit;
        if (_currentPin.length == 6) _verifyCurrent();
      } else if (_step == 2 && _newPin.length < 6) {
        _newPin += digit;
        if (_newPin.length == 6) {
          _step = 3;
        }
      } else if (_step == 3 && _confirmPin.length < 6) {
        _confirmPin += digit;
        if (_confirmPin.length == 6) _saveNewPin();
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_step == 1 && _currentPin.isNotEmpty) {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      } else if (_step == 2 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_step == 3 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  Future<void> _verifyCurrent() async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final isValid = await pinAuth.verifyPin(_currentPin);
    if (isValid) {
      setState(() => _step = 2);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'Current PIN is incorrect.';
        _currentPin = '';
      });
    }
  }

  Future<void> _saveNewPin() async {
    if (_newPin != _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = 'New PINs do not match. Try again.';
        _newPin = '';
        _confirmPin = '';
        _step = 2;
      });
      return;
    }

    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    await pinAuth.setPin(_newPin);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN successfully updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    String activeInput;

    if (_step == 1) {
      title = 'Enter Current 6-Digit PIN';
      activeInput = _currentPin;
    } else if (_step == 2) {
      title = 'Enter New 6-Digit PIN';
      activeInput = _newPin;
    } else {
      title = 'Confirm New 6-Digit PIN';
      activeInput = _confirmPin;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          // 6 Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              final isFilled = index < activeInput.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isFilled ? theme.colorScheme.primary : Colors.white30,
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          // Mini Numeric Pad
          _buildMiniKeypad(theme),
        ],
      ),
    );
  }

  Widget _buildMiniKeypad(ThemeData theme) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 56, height: 50),
            _buildKey('0'),
            SizedBox(
              width: 56,
              height: 50,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                onPressed: _onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKey(d)).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 56,
      height: 50,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
