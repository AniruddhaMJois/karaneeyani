import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = false;
  bool _isLoading = false;

  bool _isPasswordStrong(String password) {
    // Requires at least 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
    final regex = RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    return regex.hasMatch(password);
  }

  void _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    // Developer bypass for quick access
    if (_emailController.text == '1' && _passwordController.text == '1') {
      setState(() => _isLoading = true);
      final auth = Provider.of<AuthService>(context, listen: false);
      final error = await auth.signInAnonymously();
      
      if (mounted) {
        setState(() => _isLoading = false);
        if (error != null) {
          _showError(error);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        }
      }
      return;
    }

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Passwords do not match.');
        return;
      }
      if (!_isPasswordStrong(_passwordController.text)) {
        _showError('Password must be 8+ chars and contain an uppercase, lowercase, number, and special character.');
        return;
      }
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    
    // Developer test bypass for username/password '1'
    if (_isLogin && _emailController.text == '1' && _passwordController.text == '1') {
      final error = await auth.signInAnonymously();
      if (mounted) {
        setState(() => _isLoading = false);
        if (error == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        } else {
          _showError(error);
        }
      }
      return;
    }

    String? error;
    if (_isLogin) {
      error = await auth.loginWithEmail(_emailController.text, _passwordController.text);
    } else {
      error = await auth.registerWithEmail(_emailController.text, _passwordController.text, name: _nameController.text);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showError(error);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    }
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final error = await auth.signInWithGoogle();
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        _showError(error);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ).animate().fade(duration: 800.ms).scale(delay: 200.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Karaneeyaani',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Welcome back to your flow state' : 'Begin your focused journey',
                    style: const TextStyle(color: Colors.white54),
                  ).animate().fade(delay: 600.ms),
                  
                  const SizedBox(height: 48),
                  
                  // Google Sign In Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Continue with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ).animate().fade(delay: 700.ms),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                    ],
                  ).animate().fade(delay: 800.ms),
                  const SizedBox(height: 24),

                  _buildTextField(
                    controller: _emailController,
                    icon: Icons.person_outline,
                    hint: 'Email or Phone Number',
                  ).animate().fade(delay: 900.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  
                  if (!_isLogin) ...[
                    _buildTextField(
                      controller: _nameController,
                      icon: Icons.badge_outlined,
                      hint: 'Your Name (Optional)',
                    ).animate().fade(delay: 950.ms).slideX(begin: 0.1),
                    const SizedBox(height: 16),
                  ],
                  
                  _buildTextField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    hint: 'Password',
                    isPassword: true,
                  ).animate().fade(delay: 1000.ms).slideX(begin: 0.1),
                  
                  if (!_isLogin) ...[
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      icon: Icons.lock_reset,
                      hint: 'Confirm Password',
                      isPassword: true,
                    ).animate().fade(delay: 1100.ms).slideX(begin: -0.1),
                  ],

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLogin ? 'Enter' : 'Register',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ).animate().fade(delay: 1200.ms).scale(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: Text(
                      _isLogin ? 'Create a new account' : 'I already have an account',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ).animate().fade(delay: 1400.ms),
                ],
              ),
             ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
