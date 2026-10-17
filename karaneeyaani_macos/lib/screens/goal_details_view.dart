import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../providers/navigation_provider.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/goal_creation_sheet.dart';

class GoalDetailsView extends StatefulWidget {
  final DatabaseService dbService;
  final GoalModel goal;

  const GoalDetailsView({
    super.key,
    required this.dbService,
    required this.goal,
  });

  @override
  State<GoalDetailsView> createState() => _GoalDetailsViewState();
}

class _GoalDetailsViewState extends State<GoalDetailsView> {
  final Set<String> _selectedTaskIds = {};

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
    setState(() => _selectedTaskIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    // Listen to active goals so if this goal was updated we have latest data
    return StreamBuilder<List<GoalModel>>(
      stream: widget.dbService.activeGoals,
      builder: (context, goalSnapshot) {
        final activeGoals = goalSnapshot.data ?? [];
        final currentGoal = activeGoals.firstWhere(
          (g) => g.id == widget.goal.id,
          orElse: () => widget.goal,
        );

        return StreamBuilder<List<TaskModel>>(
          stream: widget.dbService.activeTasks,
          builder: (context, taskSnapshot) {
            final allTasks = taskSnapshot.data ?? [];
            final goalTasks = allTasks.where((t) => t.goalId == currentGoal.id).toList();

            // Sort: Incomplete first, completed tasks sit down at the bottom
            goalTasks.sort((a, b) {
              if (a.isDone && !b.isDone) return 1;
              if (!a.isDone && b.isDone) return -1;
              return a.order.compareTo(b.order);
            });

            final completedCount = goalTasks.where((t) => t.isDone).length;
            final totalCount = goalTasks.length;
            final progress = totalCount == 0 ? 0.0 : (completedCount / totalCount);

            final isSelectionMode = _selectedTaskIds.isNotEmpty;

            return Column(
              children: [
                // Top Header / Navigation Bar
                _buildHeader(context, currentGoal, theme),
                const Divider(color: Colors.white10, height: 1),

                // Main Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    children: [
                      // Goal Summary Card
                      _buildGoalSummaryCard(currentGoal, progress, completedCount, totalCount, theme),
                      const SizedBox(height: 24),

                      // Sub-tasks header & actions
                      Row(
                        children: [
                          Icon(Icons.checklist_rounded, color: theme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'SUB-TASKS ($totalCount)',
                            style: TextStyle(
                              color: theme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          if (isSelectionMode) ...[
                            TextButton.icon(
                              onPressed: () {
                                for (final id in _selectedTaskIds) {
                                  widget.dbService.moveToCompleted(id);
                                }
                                _clearSelection();
                              },
                              icon: const Icon(Icons.archive_outlined, size: 16),
                              label: const Text('Move Selected to Completed'),
                              style: TextButton.styleFrom(foregroundColor: Colors.tealAccent),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final ids = Set<String>.from(_selectedTaskIds);
                                for (final id in ids) {
                                  widget.dbService.moveTaskToTrash(id);
                                }
                                _clearSelection();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Moved ${ids.length} tasks to Trash'),
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      onPressed: () {
                                        for (final id in ids) {
                                          widget.dbService.restoreTask(id);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Trash Selected'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearSelection,
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: () => _openTaskCreator(context, currentGoal.id),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Task to Goal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Task list
                      if (goalTasks.isEmpty)
                        _buildEmptyTasksState(context, currentGoal.id, theme)
                      else
                        ...goalTasks.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildTaskCard(t, theme, isSelectionMode),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, GoalModel goal, ColorScheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back to Goals',
            onPressed: () => context.read<NavigationProvider>().navigateTo(DesktopNavView.goals),
          ),
          const SizedBox(width: 8),
          Text(
            goal.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Move goal to completed
          OutlinedButton.icon(
            onPressed: () {
              widget.dbService.moveGoalToCompleted(goal.id);
              context.read<NavigationProvider>().navigateTo(DesktopNavView.goals);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Moved "${goal.title}" to Completed Goals')),
              );
            },
            icon: const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Complete Goal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.tealAccent,
              side: const BorderSide(color: Colors.tealAccent),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
            tooltip: 'Edit Goal',
            onPressed: () => _openGoalEditor(context, goal),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            tooltip: 'Move Goal to Trash',
            onPressed: () {
              widget.dbService.moveGoalToTrash(goal.id);
              context.read<NavigationProvider>().navigateTo(DesktopNavView.goals);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Moved "${goal.title}" to Trash'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => widget.dbService.restoreGoal(goal.id),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSummaryCard(
    GoalModel goal,
    double progress,
    int completedCount,
    int totalCount,
    ColorScheme theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (goal.category.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    goal.category,
                    style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (goal.deadline != null) ...[
                Icon(Icons.event_rounded, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Text(
                  'Deadline: ${DateFormat('MMMM d, yyyy').format(goal.deadline!)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              goal.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                progress == 1.0 ? const Color(0xFF2ECC71) : theme.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Done',
                style: TextStyle(
                  color: progress == 1.0 ? const Color(0xFF2ECC71) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '$completedCount of $totalCount sub-tasks completed',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task, ColorScheme theme, bool isSelectionMode) {
    final isDone = task.isDone;
    final isSelected = _selectedTaskIds.contains(task.id);

    return InkWell(
      onTap: isSelectionMode ? () => _toggleSelection(task.id) : null,
      onLongPress: () => _toggleSelection(task.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primary.withOpacity(0.15)
              : (isDone ? const Color(0xFF0D2818).withOpacity(0.4) : Colors.white.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.primary
                : (isDone ? const Color(0xFF2ECC71).withOpacity(0.5) : Colors.white10),
            width: (isDone || isSelected) ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: theme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (_) => _toggleSelection(task.id),
              ),
              const SizedBox(width: 8),
            ],
            // Checkbox
            Checkbox(
              value: isDone,
              activeColor: const Color(0xFF2ECC71),
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                widget.dbService.toggleTaskDone(task.id, val ?? false);
              },
            ),
            const SizedBox(width: 10),

            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: isDone ? const Color(0xFF2ECC71) : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDone ? const Color(0xFF2ECC71).withOpacity(0.7) : Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (task.scheduledDate != null || task.scheduledTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (task.scheduledDate != null) ...[
                          Icon(Icons.calendar_today_rounded, size: 12, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d').format(task.scheduledDate!),
                            style: TextStyle(fontSize: 11, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (task.scheduledTime != null) ...[
                          Icon(Icons.access_time_rounded, size: 12, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            task.scheduledTime!,
                            style: TextStyle(fontSize: 11, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Move to Completed List button (Outbox button requested by user)
            IconButton(
              icon: const Icon(Icons.archive_outlined, size: 18),
              color: isDone ? const Color(0xFF2ECC71) : Colors.white54,
              tooltip: 'Move to Completed Items list',
              onPressed: () {
                widget.dbService.moveToCompleted(task.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Moved "${task.title}" to Completed Items')),
                );
              },
            ),

            // Edit Task button
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
              tooltip: 'Edit Task',
              onPressed: () => _openTaskEditor(context, task),
            ),

            // Delete Task button (Recycle Bin with 4-second undo)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              tooltip: 'Move to Trash',
              onPressed: () => _deleteTask(task),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksState(BuildContext context, String goalId, ColorScheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.add_task_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            'No tasks added to this goal yet',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _openTaskCreator(context, goalId),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add First Task'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _openTaskCreator(BuildContext context, String goalId) {
    showDialog(
      context: context,
      builder: (_) => TaskCreationSheet(
        dbService: widget.dbService,
        initialGoalId: goalId,
      ),
    );
  }

  void _openTaskEditor(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (_) => TaskCreationSheet(
        dbService: widget.dbService,
        taskToEdit: task,
      ),
    );
  }

  void _openGoalEditor(BuildContext context, GoalModel goal) {
    showDialog(
      context: context,
      builder: (_) => GoalCreationSheet(
        dbService: widget.dbService,
        goalToEdit: goal,
      ),
    );
  }

  void _deleteTask(TaskModel task) {
    widget.dbService.moveTaskToTrash(task.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved "${task.title}" to Trash'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => widget.dbService.restoreTask(task.id),
        ),
      ),
    );
  }
}
