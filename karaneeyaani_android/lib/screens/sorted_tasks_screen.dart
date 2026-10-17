import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/custom_drawer.dart';
import 'daily_roadmap_screen.dart';

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
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => DailyRoadmapScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
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

              final groupTasks = List<TaskModel>.from(entry.value);
              groupTasks.sort((a, b) {
                if (a.isDone && !b.isDone) return 1;
                if (!a.isDone && b.isDone) return -1;
                if (a.endDate != null && b.endDate != null) {
                  return a.endDate!.compareTo(b.endDate!);
                }
                return a.order.compareTo(b.order);
              });

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
                  ...groupTasks.map((task) {
                    final bool isDone = task.isDone;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDone ? Colors.greenAccent.withOpacity(0.5) : Colors.white10,
                            width: isDone ? 1.5 : 1.0,
                          ),
                          color: isDone ? Colors.green.withOpacity(0.12) : null,
                        ),
                        child: GlassCard(
                          child: ListTile(
                            onTap: () {
                              TaskCreationSheet.show(context, _dbService, taskToEdit: task);
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: GestureDetector(
                              onTap: () {
                                task.isDone = !task.isDone;
                                _dbService.updateTask(task);
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone ? Colors.green : Colors.transparent,
                                  border: Border.all(color: isDone ? Colors.greenAccent : Colors.white54, width: 2),
                                ),
                                child: isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                              ),
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                  color: isDone ? Colors.white70 : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  decoration: isDone ? TextDecoration.lineThrough : null),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (task.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 6),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDone)
                                  IconButton(
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    icon: const Icon(Icons.outbox_rounded, color: Colors.greenAccent, size: 22),
                                    tooltip: 'Move to Completed Tasks',
                                    onPressed: () {
                                      _dbService.markTaskCompleted(task);
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text('"${task.title}" moved to Completed'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        margin: const EdgeInsets.all(16),
                                        duration: const Duration(seconds: 3),
                                      ));
                                    },
                                  ),
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                  tooltip: 'Edit Task',
                                  onPressed: () {
                                    TaskCreationSheet.show(context, _dbService, taskToEdit: task);
                                  },
                                ),
                                IconButton(
                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete Task',
                                  onPressed: () {
                                    _dbService.softDeleteTask(task);
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: const Text('Task moved to Bin'),
                                      action: SnackBarAction(label: 'UNDO', onPressed: () => _dbService.restoreTask(task)),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      margin: const EdgeInsets.all(16),
                                      duration: const Duration(seconds: 4),
                                    ));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
