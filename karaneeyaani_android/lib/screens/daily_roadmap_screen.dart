import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/responsive_layout.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'alarm_ringing_screen.dart';
import 'goals_screen.dart';
import 'calendar_screen.dart';

class DailyRoadmapScreen extends StatefulWidget {
  final bool openTaskSheet;
  const DailyRoadmapScreen({super.key, this.openTaskSheet = false});

  @override
  State<DailyRoadmapScreen> createState() => _DailyRoadmapScreenState();
}

class _DailyRoadmapScreenState extends State<DailyRoadmapScreen> {
  late DatabaseService _dbService;
  StreamSubscription? _alarmSubscription;
  bool _isAlarmScreenShowing = false;
  Set<String> _selectedTasks = {};

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTasks.contains(taskId)) {
        _selectedTasks.remove(taskId);
      } else {
        _selectedTasks.add(taskId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);

    try {
      _alarmSubscription = Alarm.ringing.listen((alarmSet) {
        for (final alarmSettings in alarmSet.alarms) {
          _showStopAlarmDialog(alarmSettings);
        }
      });
    } catch (e) {
      debugPrint('Alarm stream listen error: $e');
    }

    if (widget.openTaskSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TaskCreationSheet.show(context, _dbService, initialDate: DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  void _showStopAlarmDialog(AlarmSettings settings) {
    if (!mounted || _isAlarmScreenShowing) return;
    _isAlarmScreenShowing = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AlarmRingingScreen(
          alarmSettings: settings,
          dbService: _dbService,
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      if (mounted) {
        _isAlarmScreenShowing = false;
      }
    });
  }

  void _showTaskDoneToast(TaskModel task) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Task "${task.title}" completed!', style: const TextStyle(color: Colors.white))),
          ],
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () => _dbService.restoreCompletedTaskById(task.id),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showExtendTaskSheet(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TaskExtensionSheet(
        task: task,
        onExtend: (dates) {
          _dbService.extendTask(task, dates);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task extended across ${dates.length} days.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }

  void _showEditProgressDialog(TaskModel task) {
    final controller = TextEditingController(text: task.progressStatus);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Update Progress', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Record what has been done...',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              task.progressStatus = controller.text.trim();
              _dbService.updateTask(task);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _dbService.activeTasks,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))));
        }

        final tasks = snapshot.data ?? [];
        tasks.sort((a, b) {
          if (a.isDone && !b.isDone) return 1;
          if (!a.isDone && b.isDone) return -1;
          return a.order.compareTo(b.order);
        });

        return ResponsiveLayout(
          mobileBody: _buildMobileLayout(tasks),
          desktopBody: _buildDesktopLayout(tasks),
        );
      },
    );
  }

  Widget _buildMobileLayout(List<TaskModel> tasks) {
    return Scaffold(
      drawer: const CustomDrawer(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileHeader(tasks),
              Expanded(
                child: _buildTaskListContent(tasks, isDesktop: false),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildDesktopLayout(List<TaskModel> tasks) {
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(
            width: 280,
            child: CustomDrawer(),
          ),
          Expanded(
            child: Container(
              decoration: _buildBackgroundDecoration(),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDesktopHeader(tasks),
                    Expanded(
                      child: _buildTaskListContent(tasks, isDesktop: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(List<TaskModel> tasks) {
    final todayStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_selectedTasks.isNotEmpty)
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedTasks.clear()))
          else
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedTasks.isNotEmpty ? '${_selectedTasks.length} Selected' : "Today's Arena",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
                if (_selectedTasks.isEmpty)
                  Text(
                    todayStr,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTasks.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      if (_selectedTasks.length == tasks.length) {
                        _selectedTasks.clear();
                      } else {
                        _selectedTasks = tasks.map((t) => t.id).toSet();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    for (final id in _selectedTasks) {
                      final t = tasks.firstWhere((t) => t.id == id);
                      _dbService.softDeleteTask(t);
                    }
                    setState(() => _selectedTasks.clear());
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.flag_rounded, color: Colors.amberAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.event_note_rounded, color: Colors.purpleAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(List<TaskModel> tasks) {
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedTasks.isNotEmpty ? '${_selectedTasks.length} Selected' : "Today's Arena",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                todayStr,
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTasks.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      if (_selectedTasks.length == tasks.length) {
                        _selectedTasks.clear();
                      } else {
                        _selectedTasks = tasks.map((t) => t.id).toSet();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    for (final id in _selectedTasks) {
                      final t = tasks.firstWhere((t) => t.id == id);
                      _dbService.softDeleteTask(t);
                    }
                    setState(() => _selectedTasks.clear());
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _selectedTasks.clear()),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.flag_rounded, color: Colors.amberAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.event_note_rounded, color: Colors.purpleAccent),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => TaskCreationSheet.show(context, _dbService, initialDate: DateTime.now()),
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Commit Intent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ).animate().scale(delay: 500.ms);
  }

  Widget _buildTaskListContent(List<TaskModel> tasks, {required bool isDesktop}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('Your arena is clear for today.', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Add tasks below to start your flow state.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
            ),
          ],
        ),
      ).animate().fade(duration: 800.ms);
    }

    final sortedTasks = List<TaskModel>.from(tasks);
    sortedTasks.sort((a, b) {
      if (a.isDone && !b.isDone) return 1;
      if (!a.isDone && b.isDone) return -1;
      return a.order.compareTo(b.order);
    });

    Widget reorderableList = ReorderableListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: sortedTasks.length,
      onReorderItem: (oldIndex, newIndex) {
        final item = sortedTasks.removeAt(oldIndex);
        sortedTasks.insert(newIndex, item);
        _dbService.updateTaskOrders(sortedTasks);
      },
      itemBuilder: (context, index) {
        final task = sortedTasks[index];
        return Padding(
          key: ValueKey(task.id),
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTaskCard(task, index),
        );
      },
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: reorderableList,
        ),
      );
    }

    return reorderableList;
  }

  Widget _buildTaskCard(TaskModel task, int index) {
    final bool isOverdue = task.endDate != null && task.endDate!.isBefore(DateTime.now());
    final bool isDone = task.isDone;
    final bool isSelected = _selectedTasks.contains(task.id);
    final theme = Theme.of(context);

    return GestureDetector(
      onLongPress: () => _toggleSelection(task.id),
      onTap: _selectedTasks.isNotEmpty ? () => _toggleSelection(task.id) : null,
      child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected
              ? [
                  Colors.blueAccent.withValues(alpha: 0.3),
                  Colors.blueAccent.withValues(alpha: 0.1),
                ]
              : isDone
                  ? [
                      Colors.green.withValues(alpha: 0.2),
                      Colors.green.withValues(alpha: 0.05),
                    ]
                  : [
                      theme.colorScheme.primary.withValues(alpha: 0.25),
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? Colors.blueAccent
              : isDone
                  ? Colors.green.withValues(alpha: 0.4)
                  : theme.colorScheme.primary.withValues(alpha: 0.4),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Task Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 16.0, right: 8.0, top: 20),
                  child: Icon(Icons.drag_handle, color: Colors.white54, size: 26),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, right: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Title
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.4,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white54,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Action Icons: Extend, Edit, Delete
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Task Extension Engine Action Icon
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: const Icon(Icons.more_time_rounded, color: Colors.lightBlueAccent, size: 21),
                      tooltip: 'Extend This To...',
                      onPressed: () => _showExtendTaskSheet(task),
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
            ],
          ),

          // Inline Progress Status Field ("what has been done")
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: InkWell(
              onTap: () => _showEditProgressDialog(task),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: task.progressStatus.isNotEmpty ? theme.colorScheme.primary : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.progressStatus.isNotEmpty
                            ? task.progressStatus
                            : 'Status: What has been done... (Tap to update)',
                        style: TextStyle(
                          fontSize: 13,
                          color: task.progressStatus.isNotEmpty
                              ? Colors.white.withValues(alpha: 0.90)
                              : Colors.white38,
                          fontStyle: task.progressStatus.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dedicated "Completed" Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (task.isDone) {
                    // Undo completion
                    task.isDone = false;
                    task.status = TaskStatus.active;
                    task.completedAt = null;
                    _dbService.updateTask(task);
                  } else {
                    // Mark as Completed
                    task.isDone = true;
                    task.status = TaskStatus.completed;
                    task.completedAt = DateTime.now();
                    _showTaskDoneToast(task);
                    _dbService.markTaskCompleted(task);
                  }
                },
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: isDone ? Colors.white : Colors.greenAccent,
                ),
                label: Text(
                  isDone ? 'Completed' : 'Mark as Completed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDone ? Colors.white : Colors.greenAccent,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDone ? Colors.green.shade600 : Colors.green.withValues(alpha: 0.12),
                  elevation: isDone ? 4 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDone ? Colors.green.shade400 : Colors.greenAccent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Date, Time, and Extended Series Badges
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0, top: 4.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.endDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOverdue
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event, size: 13, color: isOverdue ? Colors.redAccent : theme.colorScheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('MMM d').format(task.endDate!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? Colors.redAccent : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (task.hasAlarm && task.alarmTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm, size: 13, color: theme.colorScheme.secondary),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('h:mm a').format(task.alarmTime!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (task.extensionSeriesId != null && (task.extendedDaysCount ?? 0) > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat_rounded, size: 13, color: Colors.blueAccent),
                        const SizedBox(width: 5),
                        Text(
                          'Extended (${task.extendedDaysCount}d)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _TaskExtensionSheet extends StatefulWidget {
  final TaskModel task;
  final Function(List<DateTime>) onExtend;

  const _TaskExtensionSheet({required this.task, required this.onExtend});

  @override
  State<_TaskExtensionSheet> createState() => _TaskExtensionSheetState();
}

class _TaskExtensionSheetState extends State<_TaskExtensionSheet> {
  String _selectedChip = '1';
  List<DateTime> _customDates = [];

  List<DateTime> _calculateTargetDates() {
    final base = widget.task.endDate ?? DateTime.now();
    final baseDay = DateTime(base.year, base.month, base.day);

    if (_selectedChip == '1') {
      return [baseDay.add(const Duration(days: 1))];
    } else if (_selectedChip == '5') {
      return List.generate(5, (i) => baseDay.add(Duration(days: i + 1)));
    } else if (_selectedChip == '10') {
      return List.generate(10, (i) => baseDay.add(Duration(days: i + 1)));
    } else if (_selectedChip == 'custom') {
      return _customDates;
    }
    return [];
  }

  Future<void> _pickDateRange() async {
    final base = widget.task.endDate ?? DateTime.now();
    final initialRange = DateTimeRange(
      start: base.add(const Duration(days: 1)),
      end: base.add(const Duration(days: 4)),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      helpText: 'Select Extension Range',
    );

    if (picked != null) {
      final List<DateTime> dates = [];
      DateTime cur = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      while (!cur.isAfter(end)) {
        dates.add(cur);
        cur = cur.add(const Duration(days: 1));
      }

      setState(() {
        _selectedChip = 'custom';
        _customDates = dates;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = _calculateTargetDates();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.more_time_rounded, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Extend This To',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Copy "${widget.task.title}" across upcoming days with independent completion states.',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 20),

          // Preset Chips: 1, 5, 10, Custom Range
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('1 Day'),
                selected: _selectedChip == '1',
                onSelected: (val) {
                  if (val) setState(() => _selectedChip = '1');
                },
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                labelStyle: TextStyle(color: _selectedChip == '1' ? Colors.white : Colors.white60),
              ),
              ChoiceChip(
                label: const Text('5 Days'),
                selected: _selectedChip == '5',
                onSelected: (val) {
                  if (val) setState(() => _selectedChip = '5');
                },
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                labelStyle: TextStyle(color: _selectedChip == '5' ? Colors.white : Colors.white60),
              ),
              ChoiceChip(
                label: const Text('10 Days'),
                selected: _selectedChip == '10',
                onSelected: (val) {
                  if (val) setState(() => _selectedChip = '10');
                },
                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                labelStyle: TextStyle(color: _selectedChip == '10' ? Colors.white : Colors.white60),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  _selectedChip == 'custom' && _customDates.isNotEmpty
                      ? '${_customDates.length} Days'
                      : 'Custom Range',
                ),
                backgroundColor: _selectedChip == 'custom'
                    ? theme.colorScheme.primary.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08),
                onPressed: _pickDateRange,
                labelStyle: TextStyle(
                  color: _selectedChip == 'custom' ? Colors.white : Colors.white60,
                  fontWeight: _selectedChip == 'custom' ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: dates.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      widget.onExtend(dates);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Extend for ${dates.length} Day${dates.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
