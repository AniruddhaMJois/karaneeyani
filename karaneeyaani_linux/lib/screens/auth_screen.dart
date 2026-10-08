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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _enteredPin = '';
        });
      }
    }
  }

  void _onBiometric() {
    // Desktop biometric fallback or unlock
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking system biometric sensors...'),
        duration: Duration(seconds: 2),
      ),
    );
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
