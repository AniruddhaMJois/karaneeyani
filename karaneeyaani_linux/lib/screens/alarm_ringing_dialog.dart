import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../services/alarm_service.dart';

class AlarmRingingDialog extends StatelessWidget {
  final TaskModel task;
  final AlarmService alarmService;

  const AlarmRingingDialog({
    super.key,
    required this.task,
    required this.alarmService,
  });

  static Future<void> show(BuildContext context, TaskModel task, AlarmService alarmService) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlarmRingingDialog(task: task, alarmService: alarmService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Material(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.secondary.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.secondary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.secondary.withOpacity(0.15),
                    border: Border.all(color: theme.secondary, width: 2),
                  ),
                  child: Icon(Icons.alarm_on_rounded, size: 44, color: theme.secondary),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.15, 1.15),
                      duration: 600.ms,
                    ),
                const SizedBox(height: 24),
                const Text(
                  'Intent Time Reached!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  task.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.secondary,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          alarmService.snoozeAlarm(task, minutes: 5);
                          Navigator.pop(context);
                        },
                        child: const Text('Snooze 5m', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.secondary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          alarmService.stopAlarm();
                          Navigator.pop(context);
                        },
                        child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
