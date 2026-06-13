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
    return ResponsiveLayout(
      mobileBody: _buildLayout(isDesktop: false),
      desktopBody: _buildLayout(isDesktop: true),
    );
  }

  Widget _buildLayout({required bool isDesktop}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                child: _buildTaskList(isDesktop: isDesktop),
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

  Widget _buildTaskList({required bool isDesktop}) {
    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.tasksForGoal(widget.goal.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
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
      },
    );
  }

  Widget _buildTaskCard(TaskModel task, int index) {
    final bool isOverdue = task.endDate != null && task.endDate!.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
          width: 1.5,
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
                  _showTaskDoneToast(task);
                  widget.dbService.markTaskCompleted(task);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
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
              trailing: PopupMenuButton<String>(
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
                  const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
