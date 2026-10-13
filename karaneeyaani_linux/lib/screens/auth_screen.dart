import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';
import '../widgets/pin_keypad.dart';
import 'desktop_shell_screen.dart';

enum AuthMode { setup, unlock }

class AuthScreen extends StatefulWidget {
  final AuthMode mode;
  final DatabaseService dbService;

  const AuthScreen({
    super.key,
    required this.mode,
    required this.dbService,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _enteredPin = '';
  String _firstEnteredPin = '';
  bool _isConfirming = false;
  bool _enableBiometrics = true;
  String _errorMessage = '';

  void _onDigit(int digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _errorMessage = '';
        _enteredPin += '$digit';
      });

      if (_enteredPin.length == 6) {
        _handlePinComplete(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _handlePinComplete(String pin) async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);

    if (widget.mode == AuthMode.setup) {
      if (!_isConfirming) {
        // Transition to confirm PIN
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        // Verify match
        if (pin == _firstEnteredPin) {
          await pinAuth.setupPin(pin, enableBiometrics: _enableBiometrics);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Please try again.';
            _enteredPin = '';
            _firstEnteredPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Unlock Mode
      final valid = await pinAuth.verifyPin(pin);
      if (valid) {
        if (mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else if (context.findAncestorWidgetOfExactType<DesktopShellScreen>() == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _onBiometric() async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final theme = Theme.of(context).colorScheme;

    if (!pinAuth.isBiometricsEnabled) {
      setState(() {
        _errorMessage = 'Biometric authentication is disabled. Please enter your 6-digit PIN.';
      });
      return;
    }

    // Step 1: Explicitly request device permission
    final bool? permissionGranted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fingerprint_rounded, color: theme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Device Permission',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Karaneeyaani is requesting permission to access your device biometric sensor for authentication.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'If granted, you will be prompted to provide fingerprint input to verify your identity.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Deny', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Allow Permission', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (permissionGranted != true) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Device permission denied. Please enter your 6-digit PIN.';
        });
      }
      return;
    }

    // Step 2: Now take the input from the hardware sensor!
    if (!mounted) return;
    final result = await showDialog<BiometricAuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BiometricInputDialog(
        pinAuth: pinAuth,
        theme: theme,
      ),
    );

    if (!mounted) return;

    if (result != null && result.status == BiometricAuthStatus.success) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (context.findAncestorWidgetOfExactType<DesktopShellScreen>() == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
        );
      }
    } else {
      // Verification failed, device missing, or cancelled: DO NOT let the user enter!
      setState(() {
        _errorMessage = result?.message ?? 'Biometric authentication failed. Enter your 6-digit PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final pinAuth = Provider.of<PinAuthService>(context);

    String title;
    String subtitle;

    if (widget.mode == AuthMode.setup) {
      if (_isConfirming) {
        title = 'Confirm your 6-digit PIN';
        subtitle = 'Re-enter your PIN to ensure accuracy';
      } else {
        title = 'Create your 6-digit PIN';
        subtitle = 'Secure your Karaneeyaani roadmap on this Linux desktop';
      }
    } else {
      title = 'Enter your PIN';
      subtitle = 'Welcome back! Unlock your workspace';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primary.withOpacity(0.1),
                  border: Border.all(color: theme.primary.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(Icons.lock_rounded, size: 36, color: theme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.white54),
              ),
              const SizedBox(height: 28),

              // PIN Keypad with Dots
              PinKeypad(
                pinLength: 6,
                currentPin: _enteredPin,
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onBiometric: pinAuth.isBiometricsEnabled ? _onBiometric : null,
                showBiometric: widget.mode == AuthMode.unlock && pinAuth.isBiometricsEnabled,
              ),

              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ).animate().shake(),

              if (widget.mode == AuthMode.setup && !_isConfirming) ...[
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: CheckboxListTile(
                    value: _enableBiometrics,
                    activeColor: theme.secondary,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Biometrics if available', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    onChanged: (val) => setState(() => _enableBiometrics = val ?? false),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BiometricInputDialog extends StatefulWidget {
  final PinAuthService pinAuth;
  final ColorScheme theme;

  const _BiometricInputDialog({
    required this.pinAuth,
    required this.theme,
  });

  @override
  State<_BiometricInputDialog> createState() => _BiometricInputDialogState();
}

class _BiometricInputDialogState extends State<_BiometricInputDialog> {
  String _statusText = 'Waiting for fingerprint sensor input...';
  String _detailText = 'Please scan your enrolled fingerprint on the sensor.';
  bool _isProcessing = true;
  bool _isSuccess = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    final result = await widget.pinAuth.authenticateWithBiometrics();
    if (!mounted) return;

    if (result.status == BiometricAuthStatus.success) {
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusText = 'Fingerprint Verified!';
        _detailText = 'Unlocking your workspace...';
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        Navigator.pop(context, result);
      }
    } else {
      setState(() {
        _isProcessing = false;
        _isError = true;
        _statusText = result.status == BiometricAuthStatus.noDevice
            ? 'No Biometric Device Found'
            : 'Authentication Denied';
        _detailText = result.message;
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Navigator.pop(context, result);
      }
    }
  }

  @override
  void dispose() {
    widget.pinAuth.cancelBiometricAuth();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor = widget.theme.primary;
    IconData iconData = Icons.fingerprint_rounded;

    if (_isSuccess) {
      iconColor = Colors.greenAccent;
      iconData = Icons.check_circle_rounded;
    } else if (_isError) {
      iconColor = Colors.redAccent;
      iconData = Icons.error_outline_rounded;
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF16161E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.12),
                border: Border.all(color: iconColor.withOpacity(0.4), width: 2),
              ),
              child: Icon(iconData, size: 44, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: TextStyle(
                color: _isError ? Colors.redAccent : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _detailText,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.pinAuth.cancelBiometricAuth();
            Navigator.pop(
              context,
              const BiometricAuthResult(
                BiometricAuthStatus.cancelled,
                'Biometric input cancelled by user.',
              ),
            );
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

