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
                  pageBuilder: (context, animation, secondaryAnimation) => const DailyRoadmapScreen(),
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

          final allTasks = snapshot.data!;

          // Group and consolidate extended series
          // Find all tasks per extensionSeriesId
          final Map<String, List<TaskModel>> seriesMap = {};
          final List<TaskModel> standaloneTasks = [];

          for (var t in allTasks) {
            if (t.extensionSeriesId != null && t.extensionSeriesId!.isNotEmpty) {
              seriesMap.putIfAbsent(t.extensionSeriesId!, () => []).add(t);
            } else {
              standaloneTasks.add(t);
            }
          }

          // Build consolidated items list
          final List<TaskModel> consolidatedList = List.from(standaloneTasks);

          // For each series, pick the earliest instance as the consolidated representative
          for (var entry in seriesMap.entries) {
            final series = entry.value;
            series.sort((a, b) {
              if (a.endDate == null) return 1;
              if (b.endDate == null) return -1;
              return a.endDate!.compareTo(b.endDate!);
            });
            final rep = series.first;
            consolidatedList.add(rep);
          }

          // Sort consolidated items by endDate
          consolidatedList.sort((a, b) {
            if (a.endDate == null && b.endDate == null) return 0;
            if (a.endDate == null) return 1;
            if (b.endDate == null) return -1;
            return a.endDate!.compareTo(b.endDate!);
          });

          // Group by date sections
          final Map<String, List<TaskModel>> groupedTasks = {};
          for (var task in consolidatedList) {
            final section = task.endDate != null ? _getSectionHeader(task.endDate!) : 'No Date';
            groupedTasks.putIfAbsent(section, () => []).add(task);
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: groupedTasks.entries.map((entry) {
              if (entry.value.isEmpty) return const SizedBox.shrink();

              final groupTasks = List<TaskModel>.from(entry.value);

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
                            color: _getSectionColor(entry.key).withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...groupTasks.map((task) {
                    final bool isDone = task.isDone;
                    final isExtended = task.extensionSeriesId != null && task.extensionSeriesId!.isNotEmpty;
                    final seriesItems = isExtended ? seriesMap[task.extensionSeriesId] : null;
                    final totalDays = task.extendedDaysCount ?? (seriesItems?.length ?? 1);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDone ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white12,
                            width: isDone ? 1.5 : 1.0,
                          ),
                          color: isDone ? Colors.green.withValues(alpha: 0.12) : null,
                        ),
                        child: GlassCard(
                          child: InkWell(
                            onTap: () {
                              TaskCreationSheet.show(context, _dbService, taskToEdit: task);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          task.isDone = !task.isDone;
                                          if (task.isDone) {
                                            task.status = TaskStatus.completed;
                                            task.completedAt = DateTime.now();
                                            _dbService.markTaskCompleted(task);
                                          } else {
                                            task.status = TaskStatus.active;
                                            task.completedAt = null;
                                            _dbService.updateTask(task);
                                          }
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          margin: const EdgeInsets.only(top: 2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isDone ? Colors.green : Colors.transparent,
                                            border: Border.all(color: isDone ? Colors.greenAccent : Colors.white54, width: 2),
                                          ),
                                          child: isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                color: isDone ? Colors.white70 : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            if (task.description.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(task.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                            tooltip: 'Edit Task',
                                            onPressed: () {
                                              TaskCreationSheet.show(context, _dbService, taskToEdit: task);
                                            },
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
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
                                    ],
                                  ),
                                  if (task.progressStatus.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_note_rounded, size: 15, color: Colors.white54),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              task.progressStatus,
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (task.endDate != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.access_time, size: 12, color: Colors.blueAccent),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('MMM d, h:mm a').format(task.endDate!),
                                                style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (isExtended && totalDays > 1)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.6)),
                                          ),
                                          child: Text(
                                            'Extended for $totalDays days',
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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
