import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/task_creation_sheet.dart';

class SortedTasksScreen extends StatefulWidget {
  const SortedTasksScreen({super.key});

  @override
  State<SortedTasksScreen> createState() => _SortedTasksScreenState();
}

class _SortedTasksScreenState extends State<SortedTasksScreen> {
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: authService.user!.uid);
  }

  String _getSectionHeader(DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(today)) {
      return 'Overdue';
    } else if (end.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (end.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    } else {
      return 'Upcoming';
    }
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'Overdue':
        return Colors.redAccent;
      case 'Today':
        return Colors.orangeAccent;
      case 'Tomorrow':
        return Colors.blueAccent;
      default:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      appBar: AppBar(
        title: const Text('Calendar View'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _dbService.activeTasks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No tasks scheduled.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final tasks = snapshot.data!;
          // Sort tasks sequentially by end date, putting nulls at the end
          tasks.sort((a, b) {
            if (a.endDate == null && b.endDate == null) return 0;
            if (a.endDate == null) return 1;
            if (b.endDate == null) return -1;
            return a.endDate!.compareTo(b.endDate!);
          });

          // Group tasks
          final Map<String, List<TaskModel>> groupedTasks = {
            'Overdue': [],
            'Today': [],
            'Tomorrow': [],
            'Upcoming': [],
            'No Date': [],
          };

          for (var task in tasks) {
            final section = task.endDate != null ? _getSectionHeader(task.endDate!) : 'No Date';
            groupedTasks[section]!.add(task);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: groupedTasks.entries.map((entry) {
              if (entry.value.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _getSectionColor(entry.key), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: _getSectionColor(entry.key),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: _getSectionColor(entry.key).withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...entry.value.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GlassCard(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              task.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    child: Text(task.description,
                                        style: const TextStyle(color: Colors.white70)),
                                  ),
                                if (task.endDate != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.blueAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy • h:mm a').format(task.endDate!),
                                        style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                              onPressed: () => _dbService.markTaskCompleted(task),
                            ),
                          ),
                        ),
                      )),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
