import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

  void _dismissAlarm() async {
    await Alarm.stop(widget.alarmSettings.id);
    
    // Complete task if payload exists
    if (widget.dbService != null && widget.alarmSettings.payload != null) {
      await widget.dbService!.markTaskCompletedById(widget.alarmSettings.payload!);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _snoozeAlarm() async {
    final now = DateTime.now();
    final snoozeTime = now.add(Duration(minutes: _snoozeMinutes));
    
    // Stop current
    await Alarm.stop(widget.alarmSettings.id);
    
    // Create new snoozed alarm
    final newSettings = widget.alarmSettings.copyWith(
      id: widget.alarmSettings.id,
      dateTime: snoozeTime,
    );
    await Alarm.set(alarmSettings: newSettings);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snoozed for $_snoozeMinutes minutes.'),
          backgroundColor: Colors.orange,
        )
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Immersive dark
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.redAccent.withValues(alpha: 0.5), Colors.black],
              radius: 1.5,
              center: Alignment.center,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm_on, size: 100, color: Colors.white)
                  .animate(onPlay: (controller) => controller.repeat())
                  .shake(hz: 4, curve: Curves.easeInOut),
              const SizedBox(height: 32),
              const Text('Time to Focus!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text(
                widget.alarmSettings.notificationSettings.body ?? 'Your task is starting.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 64),
              // Snooze options
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Snooze for:', style: TextStyle(color: Colors.white54, fontSize: 18)),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _snoozeMinutes,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold),
                    underline: Container(height: 2, color: Colors.orange),
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
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _snoozeAlarm,
                    child: const Text('SNOOZE', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _dismissAlarm,
                    child: const Text('DISMISS', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
