import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';

class SortedTasksView extends StatefulWidget {
  final DatabaseService dbService;

  const SortedTasksView({super.key, required this.dbService});

  @override
  State<SortedTasksView> createState() => _SortedTasksViewState();
}

class _SortedTasksViewState extends State<SortedTasksView> {
  final Set<String> _selectedTaskIds = {};
  String _searchQuery = '';

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.activeTasks,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final filteredTasks = allTasks.where((t) {
          if (_searchQuery.isEmpty) return true;
          return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Categorize into sections
        final List<TaskModel> overdue = [];
        final List<TaskModel> todayTasks = [];
        final List<TaskModel> tomorrowTasks = [];
        final List<TaskModel> upcomingTasks = [];
        final List<TaskModel> noDateTasks = [];

        for (final task in filteredTasks) {
          if (task.scheduledDate == null) {
            noDateTasks.add(task);
          } else {
            final taskDate = DateTime(
              task.scheduledDate!.year,
              task.scheduledDate!.month,
              task.scheduledDate!.day,
            );
            if (taskDate.isBefore(today) && !task.isDone) {
              overdue.add(task);
            } else if (taskDate.isAtSameMomentAs(today)) {
              todayTasks.add(task);
            } else if (taskDate.isAtSameMomentAs(tomorrow)) {
              tomorrowTasks.add(task);
            } else if (taskDate.isAfter(tomorrow)) {
              upcomingTasks.add(task);
            } else {
              // Task is done and from before today
              todayTasks.add(task);
            }
          }
        }

        // Helper to sort: Incomplete first, completed tasks sit down at bottom in green
        void sortSection(List<TaskModel> list) {
          list.sort((a, b) {
            if (a.isDone && !b.isDone) return 1;
            if (!a.isDone && b.isDone) return -1;
            final dateA = a.scheduledDate ?? DateTime(9999);
            final dateB = b.scheduledDate ?? DateTime(9999);
            final compDate = dateA.compareTo(dateB);
            if (compDate != 0) return compDate;
            return a.order.compareTo(b.order);
          });
        }

        sortSection(overdue);
        sortSection(todayTasks);
        sortSection(tomorrowTasks);
        sortSection(upcomingTasks);
        sortSection(noDateTasks);

        final isSelectionMode = _selectedTaskIds.isNotEmpty;

        return Column(
          children: [
            // Top Bar
            _buildTopBar(context, filteredTasks, isSelectionMode, theme),
            const Divider(color: Colors.white10, height: 1),

            // Timeline List
            Expanded(
              child: filteredTasks.isEmpty
                  ? _buildEmptyState(context, theme)
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      children: [
                        if (overdue.isNotEmpty)
                          _buildSection(
                            title: 'OVERDUE',
                            count: overdue.length,
                            color: Colors.redAccent,
                            icon: Icons.warning_amber_rounded,
                            tasks: overdue,
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                          ),
                        if (todayTasks.isNotEmpty)
                          _buildSection(
                            title: 'TODAY',
                            count: todayTasks.length,
                            color: theme.primary,
                            icon: Icons.today_rounded,
                            tasks: todayTasks,
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                          ),
                        if (tomorrowTasks.isNotEmpty)
                          _buildSection(
                            title: 'TOMORROW',
                            count: tomorrowTasks.length,
                            color: theme.secondary,
                            icon: Icons.wb_sunny_outlined,
                            tasks: tomorrowTasks,
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                          ),
                        if (upcomingTasks.isNotEmpty)
                          _buildSection(
                            title: 'LATER THIS MONTH & BEYOND',
                            count: upcomingTasks.length,
                            color: Colors.tealAccent,
                            icon: Icons.event_note_rounded,
                            tasks: upcomingTasks,
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                          ),
                        if (noDateTasks.isNotEmpty)
                          _buildSection(
                            title: 'NO DATE (SOMEDAY)',
                            count: noDateTasks.length,
                            color: Colors.white60,
                            icon: Icons.inbox_rounded,
                            tasks: noDateTasks,
                            theme: theme,
                            isSelectionMode: isSelectionMode,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    List<TaskModel> tasks,
    bool isSelectionMode,
    ColorScheme theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          if (isSelectionMode) ...[
            Text(
              '${_selectedTaskIds.length} tasks selected',
              style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () {
                setState(() => _selectedTaskIds.addAll(tasks.map((t) => t.id)));
              },
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Select All'),
            ),
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Deselect'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                for (final id in _selectedTaskIds) {
                  widget.dbService.moveToCompleted(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moved selected tasks to Completed Items')),
                );
              },
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: const Text('Move to Completed'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final ids = Set<String>.from(_selectedTaskIds);
                for (final id in ids) {
                  widget.dbService.moveTaskToTrash(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).clearSnackBars();
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
              label: const Text('Move to Trash'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Timeline & Future Tasks',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${tasks.length} tasks organized by schedule',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 32),
            // Search Input
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search timeline...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _openTaskCreator(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    required List<TaskModel> tasks,
    required ColorScheme theme,
    required bool isSelectionMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                '$title ($count)',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTaskCard(t, theme, isSelectionMode),
            ),
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
            // Done Checkbox
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

            // Details
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
                            DateFormat('EEE, MMM d, yyyy').format(task.scheduledDate!),
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
                          const SizedBox(width: 10),
                        ],
                        if (task.alarmEnabled) ...[
                          const Icon(Icons.alarm_on_rounded, size: 12, color: Colors.orangeAccent),
                          const SizedBox(width: 4),
                          const Text('Alarm', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
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

  Widget _buildEmptyState(BuildContext context, ColorScheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Timeline is Empty',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tasks with scheduled dates will appear here organized chronologically.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openTaskCreator(context),
            icon: const Icon(Icons.add),
            label: const Text('Add a Task'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _openTaskCreator(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => TaskCreationSheet(dbService: widget.dbService),
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
