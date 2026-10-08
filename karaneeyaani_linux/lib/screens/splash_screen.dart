import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/pin_auth_service.dart';
import '../services/database_service.dart';
import 'auth_screen.dart';
import 'desktop_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  final DatabaseService dbService;

  const SplashScreen({super.key, required this.dbService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final pinAuth = Provider.of<PinAuthService>(context, listen: false);
    if (!pinAuth.isInitialized) {
      await pinAuth.init();
    }

    if (!pinAuth.isPinSet) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            mode: AuthMode.setup,
            dbService: widget.dbService,
          ),
        ),
      );
    } else if (pinAuth.isLocked) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            mode: AuthMode.unlock,
            dbService: widget.dbService,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DesktopShellScreen(
            dbService: widget.dbService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: theme.primary.withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                ],
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset('assets/icon.png', fit: BoxFit.cover),
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            const Text(
              'Karaneeyaani',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              'Linux Desktop Edition',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 2.0,
                color: theme.primary,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 36),
            SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                color: theme.primary,
                minHeight: 3,
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}
