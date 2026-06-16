import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/responsive_layout.dart';

class GoalDetailsScreen extends StatefulWidget {
  final GoalModel goal;
  final DatabaseService dbService;

  const GoalDetailsScreen({
    super.key,
    required this.goal,
    required this.dbService,
  });

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  final Set<String> _selectedTaskIds = {};
  late final Stream<List<TaskModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = widget.dbService.tasksForGoal(widget.goal.id);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTaskIds.contains(id)) {
        _selectedTaskIds.remove(id);
      } else {
        _selectedTaskIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTaskIds.clear();
    });
  }

  void _selectAllTasks(List<TaskModel> items) {
    setState(() {
      if (_selectedTaskIds.length == items.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds.addAll(items.map((e) => e.id));
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
          onPressed: () => widget.dbService.restoreTask(task),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        return ResponsiveLayout(
          mobileBody: _buildLayout(isDesktop: false, tasks: tasks),
          desktopBody: _buildLayout(isDesktop: true, tasks: tasks),
        );
      },
    );
  }

  Widget _buildLayout({required bool isDesktop, required List<TaskModel> tasks}) {
    final isSelectionMode = _selectedTaskIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '${_selectedTaskIds.length} Selected' : widget.goal.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) 
          : null,
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select All',
              onPressed: () => _selectAllTasks(tasks),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
              tooltip: 'Complete Selected',
              onPressed: () {
                for (var task in tasks) {
                  if (_selectedTaskIds.contains(task.id)) {
                    task.isDone = true;
                    widget.dbService.updateTask(task);
                  }
                }
                _clearSelection();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Selected',
              onPressed: () {
                for (var task in tasks) {
                  if (_selectedTaskIds.contains(task.id)) {
                    widget.dbService.softDeleteTask(task);
                  }
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected tasks deleted')));
              },
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'complete_all') {
                  for (var task in tasks) {
                    if (!task.isDone) {
                      task.isDone = true;
                      widget.dbService.updateTask(task);
                    }
                  }
                } else if (value == 'delete_all') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      title: const Text('Delete All Tasks?', style: TextStyle(color: Colors.white)),
                      content: const Text('This will move all tasks in this goal to the Recycle Bin.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    for (var task in tasks) {
                      widget.dbService.softDeleteTask(task);
                    }
                  }
                } else if (value == 'delete_goal') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF2A2A2A),
                      title: const Text('Delete Goal?', style: TextStyle(color: Colors.white)),
                      content: const Text('This will move the goal and its tasks to the Recycle Bin.', style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await widget.dbService.softDeleteGoal(widget.goal);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goal moved to Recycle Bin', style: TextStyle(color: Colors.white))));
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'complete_all',
                  child: Text('Complete All Tasks'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete_all',
                  child: Text('Delete All Tasks'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete_goal',
                  child: Text('Delete Goal', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ]
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.goal.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    widget.goal.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              Expanded(
                child: _buildTaskList(isDesktop: isDesktop, tasks: tasks),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskCreationSheet.show(context, widget.dbService, predefinedGoalId: widget.goal.id),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 300.ms),
    );
  }

  Widget _buildTaskList({required bool isDesktop, required List<TaskModel> tasks}) {
    tasks.sort((a, b) {
      if (a.isDone && !b.isDone) return 1;
      if (!a.isDone && b.isDone) return -1;
      return a.order.compareTo(b.order);
    });

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('No tasks in this goal yet.', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      ).animate().fade(duration: 800.ms);
    }

    Widget reorderableList = ReorderableListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 8),
      buildDefaultDragHandles: false,
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final item = tasks.removeAt(oldIndex);
        tasks.insert(newIndex, item);
        widget.dbService.updateTaskOrders(tasks);
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

    final isSelected = _selectedTaskIds.contains(task.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty;

    return InkWell(
      onLongPress: () => _toggleSelection(task.id),
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(task.id);
        } else {
          TaskCreationSheet.show(context, widget.dbService, taskToEdit: task);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.2) : (isDone ? Colors.green.withOpacity(0.15) : const Color(0xFF222222)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : (isDone ? Colors.green.withOpacity(0.4) : Colors.white12),
            width: isSelected ? 2.0 : 1.5,
          ),
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
              contentPadding: const EdgeInsets.only(right: 20, top: 12, bottom: 12, left: 8),
              leading: GestureDetector(
                onTap: () {
                  task.isDone = !task.isDone;
                  widget.dbService.updateTask(task);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? Colors.green : Colors.white.withOpacity(0.1),
                    border: Border.all(color: isDone ? Colors.greenAccent : Colors.white, width: 2),
                  ),
                  child: isDone ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              ),
              title: Text(
                task.title, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                  if (task.endDate != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue ? Colors.redAccent.withOpacity(0.15) : Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.5) : Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event, size: 12, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d, h:mm a').format(task.endDate!),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
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
                        widget.dbService.markTaskCompleted(task);
                      },
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2A2A2A),
                    onSelected: (value) {
                  if (value == 'edit') {
                    TaskCreationSheet.show(context, widget.dbService, taskToEdit: task);
                  } else if (value == 'delete') {
                    widget.dbService.softDeleteTask(task);
                  }
                },
                itemBuilder: (context) => [
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
