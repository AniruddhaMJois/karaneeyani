import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';
import 'desktop_shell_screen.dart';

class AuthScreen extends StatefulWidget {
  final DatabaseService dbService;

  const AuthScreen({
    super.key,
    required this.dbService,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
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
      _isOtpSent = true;
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
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (context.findAncestorWidgetOfExactType<DesktopShellScreen>() == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DesktopShellScreen(dbService: widget.dbService)),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Invalid OTP. Please enter the hardcoded OTP: ${PinAuthService.hardcodedOtp}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
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
                // App Logo / Icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primary.withOpacity(0.12),
                      border: Border.all(color: theme.primary.withOpacity(0.4), width: 1.5),
                    ),
                    child: Icon(
                      _isOtpSent ? Icons.sms_outlined : Icons.phone_android_rounded,
                      size: 36,
                      color: theme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Heading
                Text(
                  _isOtpSent ? 'Enter Verification Code' : 'Sign In with Phone',
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
                  _isOtpSent
                      ? 'Code sent to ${_phoneController.text.trim()}'
                      : 'Enter your phone number to access your roadmap',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Hardcoded OTP helper pill
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
                const SizedBox(height: 28),

                // Content Views
                if (!_isOtpSent) ...[
                  // Phone Number Input
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

                  // Send OTP Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _onSendOtp,
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  // OTP Input Field
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
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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

                  // Verify Button
                  SizedBox(
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
                          : const Text(
                              'Verify & Sign In',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Change Phone Number Action
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isOtpSent = false;
                        _errorMessage = '';
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _phoneFocusNode.requestFocus();
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white60),
                    label: const Text(
                      'Change phone number',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],

                // Error Message Display
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
    );
  }
}
