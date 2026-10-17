import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../services/database_service.dart';

class AlarmRingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final DatabaseService? dbService;

  const AlarmRingingScreen({super.key, required this.alarmSettings, this.dbService});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  int _snoozeMinutes = 5; // Default snooze

  void _dismissAlarm() {
    final id = widget.alarmSettings.id;
    final payload = widget.alarmSettings.payload;
    final db = widget.dbService;

    // Pop UI instantly for immediate responsiveness
    if (mounted) {
      Navigator.pop(context);
    }

    // Stop alarm in background
    Alarm.stop(id).catchError((e) {
      debugPrint('Error stopping alarm: $e');
      return true;
    });
    
    // Complete task in background
    if (db != null && payload != null) {
      db.markTaskCompletedById(payload).catchError((e) {
        debugPrint('Error completing task: $e');
      });
    }
  }

  void _snoozeAlarm() {
    final id = widget.alarmSettings.id;
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: _snoozeMinutes));
    
    final newSettings = widget.alarmSettings.copyWith(
      id: id,
      dateTime: snoozeTime,
    );

    // Pop UI instantly
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snoozed for $_snoozeMinutes minutes.'),
          backgroundColor: Colors.orange,
        )
      );
      Navigator.pop(context);
    }

    // Handle alarm logic in background
    Alarm.stop(id).then((_) {
      Alarm.set(alarmSettings: newSettings);
    }).catchError((e) {
      debugPrint('Error snoozing alarm: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final String bodyText = widget.alarmSettings.notificationSettings.body ?? '|||';
    final parts = bodyText.split('|||');
    final taskTitle = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'Task Reminder';
    final taskDesc = parts.length > 1 && parts[1].isNotEmpty 
        ? parts[1] 
        : 'Your future is created by what you do today. Keep building your empire!';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E0A3C), // Deep dark violet
                    Color(0xFF000000), // Pure black
                    Color(0xFF0D0B1A), // Deep dark blue
                  ],
                ),
              ),
            ),
          ),
          // Pulsing Glow behind icon
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.4),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.3, 1.3),
                  duration: 2.seconds,
                  curve: Curves.easeInOut,
                ),
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // App Icon with shake animation
                ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ).animate(onPlay: (controller) => controller.repeat()).shake(hz: 6, curve: Curves.easeInOut),
                
                const SizedBox(height: 48),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    taskTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle (Task Name / Body)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    taskDesc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
                ),
                
                const Spacer(flex: 2),
                
                // Snooze Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Snooze for:', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _snoozeMinutes,
                          dropdownColor: const Color(0xFF1E1E1E),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          items: [5, 10, 15, 30].map((int val) {
                            return DropdownMenuItem<int>(
                              value: val,
                              child: Text('$val mins'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _snoozeMinutes = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
                
                const SizedBox(height: 32),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Material(
                              color: Colors.white.withOpacity(0.1),
                              child: InkWell(
                                onTap: _snoozeAlarm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white24),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'SNOOZE',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.5),
                      
                      const SizedBox(width: 16),
                      
                      // Complete Button
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Material(
                              color: Colors.blueAccent.withOpacity(0.8),
                              child: InkWell(
                                onTap: _dismissAlarm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.blueAccent),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'COMPLETE',
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.5),
                    ],
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
