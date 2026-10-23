import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';
import 'desktop_shell_screen.dart';

enum AuthStep {
  registerOrLogin,
  pinUnlock,
  switchAccount,
}

class AuthScreen extends StatefulWidget {
  final DatabaseService dbService;
  final AuthStep? initialStep;

  const AuthScreen({
    super.key,
    required this.dbService,
    this.initialStep,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthStep _currentStep;

  // Controllers & Nodes
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _pinInputController = TextEditingController();

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _pinInputFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  // 6-digit PIN state for unlock
  String _enteredPin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<PinAuthService>(context, listen: false);

    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!;
    } else if (!auth.isAuthenticated || !auth.isPinSet) {
      _currentStep = AuthStep.registerOrLogin;
    } else {
      _currentStep = AuthStep.pinUnlock;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusAppropriateNode();
    });
  }

  void _focusAppropriateNode() {
    if (!mounted) return;
    switch (_currentStep) {
      case AuthStep.registerOrLogin:
      case AuthStep.switchAccount:
        _usernameFocusNode.requestFocus();
        break;
      case AuthStep.pinUnlock:
        _keyboardFocusNode.requestFocus();
        break;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinInputController.dispose();
    _usernameFocusNode.dispose();
    _pinInputFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onDigit(int digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _errorMessage = '';
        _enteredPin += '$digit';
      });

      if (_enteredPin.length == 6) {
        _handlePinUnlock(_enteredPin);
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

  Future<void> _handlePinUnlock(String pin) async {
    final auth = Provider.of<PinAuthService>(context, listen: false);
    final valid = await auth.verifyPin(pin);
    if (!mounted) return;

    if (valid) {
      if (widget.dbService.userId != auth.userId && auth.userId.isNotEmpty) {
        await widget.dbService.reloadForUser(auth.userId);
      }
      _navigateToApp();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }

  Future<void> _onSubmitCredentials({required bool isSwitching}) async {
    final username = _usernameController.text.trim();
    final pin = _pinInputController.text.trim();

    if (!PinAuthService.isValidUsername(username)) {
      setState(() {
        _errorMessage = 'Username must be 3-20 alphanumeric characters or underscores.';
      });
      _usernameFocusNode.requestFocus();
      return;
    }

    if (!PinAuthService.isValidPin(pin)) {
      setState(() {
        _errorMessage = 'PIN must be exactly 6 numeric digits.';
      });
      _pinInputFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = Provider.of<PinAuthService>(context, listen: false);
    final error = isSwitching
        ? await auth.switchAccount(username: username, pin: pin)
        : await auth.authenticateOrRegisterWithUsername(username: username, pin: pin);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (error == null) {
      await widget.dbService.reloadForUser(auth.userId);
      _navigateToApp();
    } else {
      setState(() {
        _errorMessage = error;
      });
    }
  }

  void _navigateToApp() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else if (context.findAncestorWidgetOfExactType<DesktopShellScreen>() == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.backspace) {
        _onBackspace();
      } else if (key == LogicalKeyboardKey.numpad0 || key == LogicalKeyboardKey.digit0) {
        _onDigit(0);
      } else if (key == LogicalKeyboardKey.numpad1 || key == LogicalKeyboardKey.digit1) {
        _onDigit(1);
      } else if (key == LogicalKeyboardKey.numpad2 || key == LogicalKeyboardKey.digit2) {
        _onDigit(2);
      } else if (key == LogicalKeyboardKey.numpad3 || key == LogicalKeyboardKey.digit3) {
        _onDigit(3);
      } else if (key == LogicalKeyboardKey.numpad4 || key == LogicalKeyboardKey.digit4) {
        _onDigit(4);
      } else if (key == LogicalKeyboardKey.numpad5 || key == LogicalKeyboardKey.digit5) {
        _onDigit(5);
      } else if (key == LogicalKeyboardKey.numpad6 || key == LogicalKeyboardKey.digit6) {
        _onDigit(6);
      } else if (key == LogicalKeyboardKey.numpad7 || key == LogicalKeyboardKey.digit7) {
        _onDigit(7);
      } else if (key == LogicalKeyboardKey.numpad8 || key == LogicalKeyboardKey.digit8) {
        _onDigit(8);
      } else if (key == LogicalKeyboardKey.numpad9 || key == LogicalKeyboardKey.digit9) {
        _onDigit(9);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final auth = Provider.of<PinAuthService>(context);

    String heading;
    String subtitle;
    IconData headerIcon;

    switch (_currentStep) {
      case AuthStep.registerOrLogin:
        headerIcon = Icons.account_circle_outlined;
        heading = 'Welcome to Karaneeyaani';
        subtitle = 'Sign in or register your Windows workspace with a Username and 6-digit PIN';
        break;
      case AuthStep.pinUnlock:
        headerIcon = Icons.lock_outline_rounded;
        heading = 'Enter 6-Digit PIN';
        subtitle = auth.userName.isNotEmpty
            ? 'Welcome back, ${auth.userName}! Enter PIN to unlock'
            : 'Welcome back! Enter your 6-digit PIN to continue';
        break;
      case AuthStep.switchAccount:
        headerIcon = Icons.switch_account_rounded;
        heading = 'Switch Account';
        subtitle = 'Active internet connection required to verify credentials against cloud';
        break;
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: _currentStep == AuthStep.pinUnlock,
      onKeyEvent: _currentStep == AuthStep.pinUnlock ? _handleKeyEvent : null,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: _currentStep == AuthStep.pinUnlock ? 380 : 440,
              ),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App / Step Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primary.withOpacity(0.12),
                        border: Border.all(color: theme.primary.withOpacity(0.4), width: 1.5),
                      ),
                      child: Icon(headerIcon, size: 36, color: theme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Heading
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Views
                  if (_currentStep == AuthStep.pinUnlock) ...[
                    _buildPinUnlockView(theme, auth),
                  ] else ...[
                    _buildCredentialsForm(theme, auth, isSwitching: _currentStep == AuthStep.switchAccount),
                  ],

                  // Error Message
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().shake(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsForm(ColorScheme theme, PinAuthService auth, {required bool isSwitching}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Online Badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 14, color: Colors.cyanAccent),
                SizedBox(width: 6),
                Text(
                  'Internet Connection Required',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Username Field
        TextField(
          controller: _usernameController,
          focusNode: _usernameFocusNode,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          ],
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: const TextStyle(color: Colors.white60),
            hintText: 'e.g. aniruddha_jois',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.person_outline_rounded, color: Colors.white60),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.primary, width: 1.5),
            ),
          ),
          onSubmitted: (_) => _pinInputFocusNode.requestFocus(),
        ),
        const SizedBox(height: 16),

        // 6-digit PIN Field
        TextField(
          controller: _pinInputController,
          focusNode: _pinInputFocusNode,
          keyboardType: TextInputType.number,
          obscureText: _obscurePin,
          maxLength: 6,
          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            labelText: '6-Digit Numeric PIN',
            labelStyle: const TextStyle(color: Colors.white60, letterSpacing: 0),
            hintText: '••••••',
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
            prefixIcon: const Icon(Icons.lock_clock_outlined, color: Colors.white60),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.primary, width: 1.5),
            ),
          ),
          onSubmitted: (_) => _onSubmitCredentials(isSwitching: isSwitching),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : () => _onSubmitCredentials(isSwitching: isSwitching),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    isSwitching ? 'Verify & Switch Account' : 'Sign In / Register',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        if (isSwitching) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                setState(() {
                  _currentStep = AuthStep.pinUnlock;
                  _errorMessage = '';
                  _usernameController.clear();
                  _pinInputController.clear();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _keyboardFocusNode.requestFocus();
                });
              }
            },
            child: const Text('Cancel & Return to PIN Unlock', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ],
    );
  }

  Widget _buildPinUnlockView(ColorScheme theme, PinAuthService auth) {
    return Column(
      children: [
        // 6 PIN Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final isFilled = index < _enteredPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? theme.primary : Colors.transparent,
                border: Border.all(
                  color: isFilled ? theme.primary : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // Keypad Grid
        Column(
          children: [
            _buildKeypadRow(['1', '2', '3'], theme),
            const SizedBox(height: 12),
            _buildKeypadRow(['4', '5', '6'], theme),
            const SizedBox(height: 12),
            _buildKeypadRow(['7', '8', '9'], theme),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 68, height: 68),
                _buildNumberButton('0', theme),
                _buildActionButton(
                  icon: Icons.backspace_outlined,
                  onPressed: _onBackspace,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = AuthStep.switchAccount;
              _enteredPin = '';
              _errorMessage = '';
              _usernameController.clear();
              _pinInputController.clear();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _usernameFocusNode.requestFocus();
            });
          },
          icon: const Icon(Icons.switch_account_rounded, size: 16, color: Colors.white54),
          label: const Text(
            'Sign out / Switch account',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, ColorScheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildNumberButton(n, theme)).toList(),
    );
  }

  Widget _buildNumberButton(String number, ColorScheme theme) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(34),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          splashColor: theme.primary.withOpacity(0.2),
          onTap: () => _onDigit(int.parse(number)),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 24,
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
    String? tooltip,
  }) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(34),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          splashColor: Colors.white12,
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 24, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
