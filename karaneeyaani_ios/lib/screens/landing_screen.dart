import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/goal_creation_sheet.dart';
import 'goals_screen.dart';
import 'daily_roadmap_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openTaskSheet(BuildContext context, DatabaseService dbService) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DailyRoadmapScreen(openTaskSheet: true)),
    );
  }

  void _openGoalSheet(BuildContext context, DatabaseService dbService) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen(openGoalSheet: true)),
    );
  }

  void _goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DailyRoadmapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final dbService = DatabaseService(userId: auth.user!.uid);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                
                // App Logo and Title
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(curve: Curves.easeOutBack),
                
                const SizedBox(height: 32),
                
                Text(
                  'Welcome to\nKaraneeyaani',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 16),
                
                Text(
                  'What would you like to achieve today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
                
                const Spacer(),
                
                // Primary Action Buttons
                _buildActionButton(
                  context,
                  icon: Icons.add_task_rounded,
                  title: 'New Task',
                  subtitle: 'Quick action item',
                  color: Colors.blueAccent,
                  onTap: () => _openTaskSheet(context, dbService),
                ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.1, end: 0),
                
                const SizedBox(height: 16),
                
                _buildActionButton(
                  context,
                  icon: Icons.flag_rounded,
                  title: 'New Goal',
                  subtitle: 'Long-term objective',
                  color: Colors.amberAccent,
                  onTap: () => _openGoalSheet(context, dbService),
                ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1, end: 0),
                
                const SizedBox(height: 32),
                
                // Secondary Action
                TextButton(
                  onPressed: () => _goToDashboard(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Go to Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ).animate().fadeIn(delay: 1000.ms),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
