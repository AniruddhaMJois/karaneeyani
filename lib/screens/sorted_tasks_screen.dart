import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/custom_drawer.dart';

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
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(today)) {
      return 'Overdue';
    } else if (end.isAtSameMomentAs(today)) {
      return 'Today - ${DateFormat('MMM d').format(end)}';
    } else if (end.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'Tomorrow - ${DateFormat('MMM d').format(end)}';
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(end);
    }
  }

  Color _getSectionColor(String section) {
    if (section == 'Overdue') return Colors.redAccent;
    if (section.startsWith('Today')) return Colors.orangeAccent;
    if (section.startsWith('Tomorrow')) return Colors.blueAccent;
    if (section == 'No Date') return Colors.white54;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: theme.surface,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        title: const Text('Future Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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

          // Group tasks dynamically
          final Map<String, List<TaskModel>> groupedTasks = {};

          for (var task in tasks) {
            final section = task.endDate != null ? _getSectionHeader(task.endDate!) : 'No Date';
            if (!groupedTasks.containsKey(section)) {
              groupedTasks[section] = [];
            }
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
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _getSectionColor(entry.key), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: _getSectionColor(entry.key),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 16, color: Colors.blueAccent),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('h:mm a').format(task.endDate!),
                                          style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 28),
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
