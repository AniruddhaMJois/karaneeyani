import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/pin_auth_service.dart';
import 'daily_roadmap_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool forceSwitchAccount;
  const AuthScreen({super.key, this.forceSwitchAccount = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = true;
  bool _isFirstTime = false;
  int _setupStep = 1; // 1: Enter new PIN, 2: Confirm new PIN
  String _enteredPin = '';
  String _firstEnteredPin = '';
  String? _errorMessage;
  int _shakeKey = 0;
  bool _isSubmitting = false;

  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkInitialState() async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final isPinSet = await pinAuth.checkIsPinSet();

    if (!mounted) return;

    setState(() {
      _isFirstTime = widget.forceSwitchAccount || !isPinSet;
      _isLoading = false;
    });

    if (isPinSet && !widget.forceSwitchAccount && pinAuth.isBiometricsEnabled) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _authenticateWithBiometrics();
        }
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final authenticated = await pinAuth.authenticateWithBiometrics(
      reason: 'Scan fingerprint or face to unlock Karaneeyaani',
    );

    if (authenticated && mounted) {
      await authService.ensureAuthenticatedUser();
      if (mounted) {
        _navigateToTodayArena();
      }
    }
  }

  void _onDigitPressed(String digit) {
    if (_isSubmitting || _enteredPin.length >= 6) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 6) {
      _handleCompletedPin(_enteredPin);
    }
  }

  void _onBackspacePressed() {
    if (_isSubmitting || _enteredPin.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _handleCompletedPin(String pin) async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isFirstTime) {
      final username = _usernameController.text.trim();
      if (username.isEmpty || !AuthService.isValidUsername(username)) {
        HapticFeedback.heavyImpact();
        setState(() {
          _shakeKey++;
          _errorMessage = 'Please enter a valid username (3-20 characters).';
          _enteredPin = '';
        });
        return;
      }

      if (_setupStep == 1) {
        HapticFeedback.mediumImpact();
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _setupStep = 2;
        });
      } else {
        if (pin == _firstEnteredPin) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isSubmitting = true;
            _errorMessage = null;
          });

          final error = await authService.authenticateOrRegisterWithUsername(
            username: username,
            pin: pin,
            pinAuth: pinAuth,
          );

          if (!mounted) return;

          setState(() {
            _isSubmitting = false;
          });

          if (error != null) {
            HapticFeedback.heavyImpact();
            setState(() {
              _shakeKey++;
              _errorMessage = error;
              _enteredPin = '';
              _firstEnteredPin = '';
              _setupStep = 1;
            });
          } else {
            await _promptBiometricPermissionAndFinish();
          }
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _shakeKey++;
            _errorMessage = 'PINs do not match. Please start over.';
            _enteredPin = '';
            _firstEnteredPin = '';
            _setupStep = 1;
          });
        }
      }
    } else {
      // Offline 0ms Local PIN Verification
      final isValid = await pinAuth.verifyPin(pin);
      if (isValid) {
        HapticFeedback.mediumImpact();
        await authService.ensureAuthenticatedUser();
        if (mounted) {
          _navigateToTodayArena();
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _shakeKey++;
          _errorMessage = 'Incorrect PIN. Please try again.';
          _enteredPin = '';
        });
      }
    }
  }

  Future<void> _promptBiometricPermissionAndFinish() async {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    final isBioSupported = await pinAuth.isBiometricsSupported();

    if (isBioSupported && mounted) {
      final enableBio = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildBiometricPermissionSheet(ctx),
      );

      if (enableBio == true) {
        final authenticated = await pinAuth.authenticateWithBiometrics(
          reason: 'Verify biometric access for Karaneeyaani',
        );
        await pinAuth.setBiometricsEnabled(authenticated);
      } else {
        await pinAuth.setBiometricsEnabled(false);
      }
    } else {
      await pinAuth.setBiometricsEnabled(false);
    }

    await authService.ensureAuthenticatedUser();

    if (mounted) {
      _navigateToTodayArena();
    }
  }

  Widget _buildBiometricPermissionSheet(BuildContext ctx) {
    final theme = Theme.of(ctx);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enable Biometric Unlock?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Log in faster and more securely next time using Fingerprint or Face recognition.',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.fingerprint_rounded, color: Colors.black),
              label: const Text(
                'Enable Biometrics',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Skip for Now',
                style: TextStyle(fontSize: 15, color: Colors.white54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTodayArena() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DailyRoadmapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onBackspacePressed();
      } else if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
        _onDigitPressed(key.keyLabel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinAuth = Provider.of<PinAuthService>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String title;
    String subtitle;

    if (_isFirstTime) {
      if (_setupStep == 1) {
        title = 'Sign In / Register';
        subtitle = 'Enter username and choose a 6-digit PIN';
      } else {
        title = 'Confirm Your PIN';
        subtitle = 'Re-enter your 6-digit PIN to confirm';
      }
    } else {
      title = 'Welcome Back';
      subtitle = pinAuth.username != null && pinAuth.username!.isNotEmpty
          ? 'Enter PIN for @${pinAuth.username}'
          : 'Enter your 6-digit PIN to continue';
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.primary.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                        ),
                      ).animate().fade(duration: 600.ms).scale(delay: 100.ms),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Username field if First Time / Registration
                      if (_isFirstTime && _setupStep == 1) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Username (e.g. flow_master)',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                          ),
                        ),
                      ],

                      // PIN Indicators (6 Dots)
                      AnimatedContainer(
                        key: ValueKey(_shakeKey),
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            final isFilled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                                border: Border.all(
                                  color: isFilled
                                      ? theme.colorScheme.primary
                                      : Colors.white.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                                boxShadow: isFilled
                                    ? [
                                        BoxShadow(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ),

                      // Error message or loading indicator
                      Container(
                        height: 38,
                        alignment: Alignment.center,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : (_errorMessage != null
                                ? Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ).animate().fade(duration: 200.ms).shake(offset: const Offset(4, 0))
                                : null),
                      ),
                      const SizedBox(height: 12),

                      // Numeric Keypad
                      _buildKeypad(theme, pinAuth),

                      const SizedBox(height: 16),

                      // Switch Account Option on Subsequent unlock
                      if (!_isFirstTime) ...[
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isFirstTime = true;
                              _setupStep = 1;
                              _enteredPin = '';
                              _firstEnteredPin = '';
                              _errorMessage = null;
                            });
                          },
                          icon: const Icon(Icons.switch_account_rounded, size: 18, color: Colors.white60),
                          label: const Text(
                            'Switch Account / Sign In as Different User',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, PinAuthService pinAuth) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], theme),
        const SizedBox(height: 14),
        _buildKeypadRow(['4', '5', '6'], theme),
        const SizedBox(height: 14),
        _buildKeypadRow(['7', '8', '9'], theme),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Action: Biometrics (if enabled in Unlock mode) or Back (in setup step 2)
            if (!_isFirstTime && pinAuth.isBiometricsEnabled)
              _buildActionButton(
                icon: Icons.fingerprint_rounded,
                onPressed: _authenticateWithBiometrics,
                theme: theme,
                tooltip: 'Unlock with Biometrics',
                highlight: true,
              )
            else if (_isFirstTime && _setupStep == 2)
              _buildActionButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _setupStep = 1;
                    _enteredPin = '';
                    _firstEnteredPin = '';
                    _errorMessage = null;
                  });
                },
                theme: theme,
                tooltip: 'Back to first PIN',
              )
            else
              const SizedBox(width: 72, height: 72),

            // Number 0
            _buildNumberButton('0', theme),

            // Backspace Action
            _buildActionButton(
              icon: Icons.backspace_outlined,
              onPressed: _onBackspacePressed,
              theme: theme,
              tooltip: 'Delete',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n, theme)).toList(),
    );
  }

  Widget _buildNumberButton(String number, ThemeData theme) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(36),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.25),
          highlightColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          onTap: () => _onDigitPressed(number),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required ThemeData theme,
    String? tooltip,
    bool highlight = false,
  }) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(36),
          side: highlight
              ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.25),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 28,
              color: highlight ? theme.colorScheme.primary : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
