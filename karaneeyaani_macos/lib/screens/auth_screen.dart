import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';
import 'desktop_shell_screen.dart';

enum AuthStep {
  phone,
  otp,
  name,
  pinSetup,
  pinUnlock,
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  // PIN state
  String _enteredPin = '';
  String _firstEnteredPin = '';
  bool _isConfirmingPin = false;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<PinAuthService>(context, listen: false);

    if (widget.initialStep != null) {
      _currentStep = widget.initialStep!;
    } else if (!auth.isAuthenticated) {
      _currentStep = AuthStep.phone;
    } else if (!auth.hasName) {
      _currentStep = AuthStep.name;
    } else if (!auth.isPinSet) {
      _currentStep = AuthStep.pinSetup;
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
      case AuthStep.phone:
        _phoneFocusNode.requestFocus();
        break;
      case AuthStep.otp:
        _otpFocusNode.requestFocus();
        break;
      case AuthStep.name:
        _nameFocusNode.requestFocus();
        break;
      case AuthStep.pinSetup:
      case AuthStep.pinUnlock:
        _keyboardFocusNode.requestFocus();
        break;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _nameFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.replaceAll(RegExp(r'\D'), '').length < 6) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number (at least 6 digits).';
      });
      return;
    }

    setState(() {
      _errorMessage = '';
      _currentStep = AuthStep.otp;
      _otpController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _otpFocusNode.requestFocus();
    });
  }

  Future<void> _onVerifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = Provider.of<PinAuthService>(context, listen: false);
    final success = await auth.verifyOtp(phone, otp);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (!auth.hasName) {
        setState(() {
          _currentStep = AuthStep.name;
          _errorMessage = '';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _nameFocusNode.requestFocus();
        });
      } else if (!auth.isPinSet) {
        setState(() {
          _currentStep = AuthStep.pinSetup;
          _enteredPin = '';
          _firstEnteredPin = '';
          _isConfirmingPin = false;
          _errorMessage = '';
        });
        _keyboardFocusNode.requestFocus();
      } else {
        _navigateToApp();
      }
    } else {
      setState(() {
        _errorMessage = 'Invalid OTP. Please enter the hardcoded OTP: ${PinAuthService.hardcodedOtp}';
      });
    }
  }

  Future<void> _onSaveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final auth = Provider.of<PinAuthService>(context, listen: false);
    await auth.setUserName(name);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _currentStep = AuthStep.pinSetup;
      _enteredPin = '';
      _firstEnteredPin = '';
      _isConfirmingPin = false;
      _errorMessage = '';
    });

    _keyboardFocusNode.requestFocus();
  }

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
    final auth = Provider.of<PinAuthService>(context, listen: false);

    if (_currentStep == AuthStep.pinSetup) {
      if (!_isConfirmingPin) {
        setState(() {
          _firstEnteredPin = pin;
          _enteredPin = '';
          _isConfirmingPin = true;
          _errorMessage = '';
        });
      } else {
        if (pin == _firstEnteredPin) {
          await auth.setupPin(pin);
          if (mounted) {
            _navigateToApp();
          }
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Please start over.';
            _enteredPin = '';
            _firstEnteredPin = '';
            _isConfirmingPin = false;
          });
        }
      }
    } else if (_currentStep == AuthStep.pinUnlock) {
      final valid = await auth.verifyPin(pin);
      if (valid) {
        if (mounted) {
          _navigateToApp();
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _enteredPin = '';
        });
      }
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
      } else if (key.keyLabel.isNotEmpty && RegExp(r'^[0-9]$').hasMatch(key.keyLabel)) {
        _onDigit(int.parse(key.keyLabel));
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
      case AuthStep.phone:
        headerIcon = Icons.phone_android_rounded;
        heading = 'Sign In with Phone';
        subtitle = 'Enter your phone number to access your workspace';
        break;
      case AuthStep.otp:
        headerIcon = Icons.sms_outlined;
        heading = 'Enter Verification Code';
        subtitle = 'Code sent to ${_phoneController.text.trim()}';
        break;
      case AuthStep.name:
        headerIcon = Icons.badge_outlined;
        heading = 'What should we call you?';
        subtitle = 'Enter your name to personalize your workspace';
        break;
      case AuthStep.pinSetup:
        headerIcon = Icons.lock_clock_rounded;
        if (_isConfirmingPin) {
          heading = 'Confirm 6-Digit PIN';
          subtitle = 'Re-enter your 6-digit PIN to verify';
        } else {
          heading = 'Create 6-Digit PIN';
          subtitle = 'Set a compulsory PIN required whenever opening the app';
        }
        break;
      case AuthStep.pinUnlock:
        headerIcon = Icons.lock_outline_rounded;
        heading = 'Enter 6-Digit PIN';
        subtitle = auth.userName.isNotEmpty
            ? 'Welcome back, ${auth.userName}! Enter PIN to unlock'
            : 'Welcome back! Enter your 6-digit PIN to continue';
        break;
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: _currentStep == AuthStep.pinSetup || _currentStep == AuthStep.pinUnlock,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: (_currentStep == AuthStep.pinSetup || _currentStep == AuthStep.pinUnlock) ? 380 : 420,
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
                  const SizedBox(height: 16),

                  // Step-specific views
                  if (_currentStep == AuthStep.phone) ...[
                    _buildPhoneView(theme),
                  ] else if (_currentStep == AuthStep.otp) ...[
                    _buildOtpView(theme),
                  ] else if (_currentStep == AuthStep.name) ...[
                    _buildNameView(theme),
                  ] else if (_currentStep == AuthStep.pinSetup || _currentStep == AuthStep.pinUnlock) ...[
                    _buildPinKeypadView(theme, auth),
                  ],

                  // Error Message
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
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

  Widget _buildPhoneView(ColorScheme theme) {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
          ],
          onSubmitted: (_) => _onSendOtp(),
          decoration: InputDecoration(
            labelText: 'Phone Number',
            labelStyle: const TextStyle(color: Colors.white60),
            hintText: '+91 9876543210',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.phone_rounded, color: Colors.white60),
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
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _onSendOtp,
            child: const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpView(ColorScheme theme) {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 6),
                Text(
                  'Hardcoded OTP: ${PinAuthService.hardcodedOtp}',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          focusNode: _otpFocusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 6,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _onVerifyOtp(),
          decoration: InputDecoration(
            counterText: '',
            labelText: 'Enter 6-digit OTP',
            labelStyle: const TextStyle(color: Colors.white60, letterSpacing: 0, fontSize: 14),
            hintText: PinAuthService.hardcodedOtp,
            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
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
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _onVerifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Verify & Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = AuthStep.phone;
              _errorMessage = '';
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _phoneFocusNode.requestFocus();
            });
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white60),
          label: const Text('Change phone number', style: TextStyle(color: Colors.white60, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildNameView(ColorScheme theme) {
    return Column(
      children: [
        TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onSubmitted: (_) => _onSaveName(),
          decoration: InputDecoration(
            labelText: 'Your Full Name',
            labelStyle: const TextStyle(color: Colors.white60),
            hintText: 'e.g. Aniruddha Jois',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.person_rounded, color: Colors.white60),
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
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _onSaveName,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Continue to PIN Setup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPinKeypadView(ColorScheme theme, PinAuthService auth) {
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
                if (_currentStep == AuthStep.pinSetup && _isConfirmingPin)
                  _buildActionButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () {
                      setState(() {
                        _isConfirmingPin = false;
                        _enteredPin = '';
                        _firstEnteredPin = '';
                        _errorMessage = '';
                      });
                    },
                    tooltip: 'Back',
                  )
                else
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

        if (_currentStep == AuthStep.pinUnlock) ...[
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              auth.logout();
              setState(() {
                _currentStep = AuthStep.phone;
                _enteredPin = '';
                _errorMessage = '';
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _phoneFocusNode.requestFocus();
              });
            },
            child: const Text(
              'Sign in with different account',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
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
