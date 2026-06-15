import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';
import 'package:alarm/alarm.dart';
import 'dart:async';
import 'alarm_ringing_screen.dart';
import 'sorted_tasks_screen.dart';
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
  StreamSubscription<AlarmSettings>? _alarmSubscription;
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
      _alarmSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
        _showStopAlarmDialog(alarmSettings);
      });
    } catch (e) {
      debugPrint('Alarm stream already listened to: $e');
    }

    if (widget.openTaskSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TaskCreationSheet.show(context, _dbService);
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
            Expanded(child: Text('Task "${task.title}" successfully completed!', style: const TextStyle(color: Colors.white))),
          ],
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () => _dbService.restoreTask(task),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
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
            child: Text(
              _selectedTasks.isNotEmpty ? '${_selectedTasks.length} Selected' : 'Daily Roadmap', 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _selectedTasks.isNotEmpty ? '${_selectedTasks.length} Selected' : 'Daily Roadmap', 
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2)
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
      onPressed: () => TaskCreationSheet.show(context, _dbService),
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
            const Text('Your roadmap is clear.', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      ).animate().fade(duration: 800.ms);
    }

        // We no longer sort by endDate purely, the stream is ordered by 'order'. 
        // If we want manual reordering to stick, we rely on the DB's order.

        Widget reorderableList = ReorderableListView.builder(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
          buildDefaultDragHandles: false,
          itemCount: tasks.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = tasks.removeAt(oldIndex);
            tasks.insert(newIndex, item);
            _dbService.updateTaskOrders(tasks);
          },
          itemBuilder: (context, index) {
            final task = tasks[index];
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSelected ? [
            Colors.blueAccent.withOpacity(0.3),
            Colors.blueAccent.withOpacity(0.1),
          ] : isDone ? [
            Colors.green.withOpacity(0.2),
            Colors.green.withOpacity(0.05),
          ] : [
            Theme.of(context).colorScheme.primary.withOpacity(0.25),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.blueAccent 
              : isDone ? Colors.green.withOpacity(0.4) 
              : Theme.of(context).colorScheme.primary.withOpacity(0.4),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 8.0),
              child: Icon(Icons.drag_handle, color: Colors.white54, size: 28),
            ),
          ),
          Expanded(
            child: ListTile(
              onLongPress: () => _toggleSelection(task.id),
              onTap: () {
                if (_selectedTasks.isNotEmpty) {
                  _toggleSelection(task.id);
                  return;
                }
                // Later: Edit task via tap if not done? Or just ignore.
              },
              contentPadding: const EdgeInsets.only(right: 20, top: 16, bottom: 16, left: 8),
              leading: GestureDetector(
                onTap: () {
                  if (_selectedTasks.isNotEmpty) {
                    _toggleSelection(task.id);
                    return;
                  }
                  task.isDone = !task.isDone;
                  _dbService.updateTask(task);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? Colors.blueAccent : isDone ? Colors.green : Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: isSelected ? Colors.blueAccent : isDone ? Colors.greenAccent : Colors.white, 
                      width: 2
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) 
                       : isDone ? const Icon(Icons.check, color: Colors.white, size: 20) 
                       : null,
                ),
              ),
              title: Text(
                task.title, 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.3)),
                  ],
                  if (task.endDate != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOverdue ? Colors.redAccent.withOpacity(0.15) : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.5) : Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event, size: 14, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MMM d').format(task.endDate!),
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        ),
                        if (task.hasAlarm && task.alarmTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.alarm, size: 14, color: Theme.of(context).colorScheme.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('h:mm a').format(task.alarmTime!),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  ]
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDone)
                    IconButton(
                      icon: const Icon(Icons.outbox_rounded, color: Colors.greenAccent),
                      tooltip: 'Move to Completed Tasks',
                      onPressed: () {
                        _showTaskDoneToast(task);
                        _dbService.markTaskCompleted(task);
                      },
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2A2A2A),
                    onSelected: (value) {
                  if (value == 'edit') {
                    TaskCreationSheet.show(context, _dbService, taskToEdit: task);
                  } else if (value == 'delete') {
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
                    Future.delayed(const Duration(seconds: 4), () {
                      if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
