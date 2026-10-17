import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';

class DailyRoadmapView extends StatefulWidget {
  final DatabaseService dbService;

  const DailyRoadmapView({super.key, required this.dbService});

  @override
  State<DailyRoadmapView> createState() => _DailyRoadmapViewState();
}

class _DailyRoadmapViewState extends State<DailyRoadmapView> {
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

    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.activeTasks,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final filteredTasks = allTasks.where((t) {
          if (_searchQuery.isEmpty) return true;
          return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // Sort: Incomplete first by order, completed tasks sit down at the bottom
        final sortedTasks = List<TaskModel>.from(filteredTasks);
        sortedTasks.sort((a, b) {
          if (a.isDone && !b.isDone) return 1;
          if (!a.isDone && b.isDone) return -1;
          return a.order.compareTo(b.order);
        });

        final isSelectionMode = _selectedTaskIds.isNotEmpty;

        return Column(
          children: [
            // Top Action Bar
            _buildTopBar(context, sortedTasks, isSelectionMode, theme),
            const Divider(color: Colors.white10, height: 1),

            // Task List
            Expanded(
              child: sortedTasks.isEmpty
                  ? _buildEmptyState(context)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      buildDefaultDragHandles: false,
                      itemCount: sortedTasks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = sortedTasks.removeAt(oldIndex);
                        sortedTasks.insert(newIndex, item);
                        widget.dbService.updateTaskOrders(sortedTasks);
                      },
                      itemBuilder: (context, index) {
                        final task = sortedTasks[index];
                        return Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTaskCard(task, index, theme, isSelectionMode),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, List<TaskModel> tasks, bool isSelectionMode, ColorScheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedTaskIds.length} Selected',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white70),
              tooltip: 'Select All',
              onPressed: () {
                setState(() {
                  if (_selectedTaskIds.length == tasks.length) {
                    _selectedTaskIds.clear();
                  } else {
                    _selectedTaskIds.addAll(tasks.map((t) => t.id));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Move Selected to Bin',
              onPressed: () {
                for (final id in _selectedTaskIds) {
                  final t = tasks.firstWhere((e) => e.id == id);
                  widget.dbService.softDeleteTask(t);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selected tasks moved to Recycle Bin'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ] else ...[
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Roadmap',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                ),
                Text(
                  'Order and focus on your core intents for today',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            const Spacer(),
            // Search Input
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Commit Intent', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => TaskCreationSheet.show(context, widget.dbService),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task, int index, ColorScheme theme, bool isSelectionMode) {
    final bool isDone = task.isDone;
    final bool isSelected = _selectedTaskIds.contains(task.id);
    final bool isOverdue = task.endDate != null && task.endDate!.isBefore(DateTime.now()) && !isDone;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blueAccent.withOpacity(0.18)
            : isDone
                ? Colors.green.withOpacity(0.10)
                : const Color(0xFF16161D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.blueAccent
              : isDone
                  ? Colors.greenAccent.withOpacity(0.4)
                  : isOverdue
                      ? Colors.redAccent.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
          width: isSelected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.drag_indicator, color: Colors.white38, size: 22),
            ),
          ),
          Expanded(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              onLongPress: () => _toggleSelection(task.id),
              onTap: () {
                if (isSelectionMode) {
                  _toggleSelection(task.id);
                } else {
                  TaskCreationSheet.show(context, widget.dbService, taskToEdit: task);
                }
              },
              leading: GestureDetector(
                onTap: () {
                  if (isSelectionMode) {
                    _toggleSelection(task.id);
                  } else {
                    task.isDone = !task.isDone;
                    widget.dbService.updateTask(task);
                  }
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.blueAccent
                        : isDone
                            ? Colors.green
                            : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.blueAccent
                          : isDone
                              ? Colors.greenAccent
                              : Colors.white54,
                      width: 2,
                    ),
                  ),
                  child: isSelected || isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                ),
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDone ? Colors.white60 : Colors.white,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                  if (task.endDate != null || task.hasAlarm) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (task.endDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOverdue ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isOverdue ? Colors.redAccent.withOpacity(0.5) : Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event, size: 13, color: isOverdue ? Colors.redAccent : Colors.white70),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(task.endDate!),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOverdue ? Colors.redAccent : Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        if (task.hasAlarm && task.alarmTime != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.secondary.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.alarm, size: 13, color: theme.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('h:mm a').format(task.alarmTime!),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.secondary),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: isSelectionMode
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isDone)
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            icon: const Icon(Icons.outbox_rounded, color: Colors.greenAccent, size: 22),
                            tooltip: 'Move to Completed Items',
                            onPressed: () {
                              widget.dbService.markTaskCompleted(task);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${task.title}" moved to Completed Items'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.all(16),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                          tooltip: 'Edit Task',
                          onPressed: () => TaskCreationSheet.show(context, widget.dbService, taskToEdit: task),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Task',
                          onPressed: () {
                            widget.dbService.softDeleteTask(task);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Task moved to Recycle Bin'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () => widget.dbService.restoreTask(task),
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          const Text(
            'All intents completed for today!',
            style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Commit Intent" above to add new actions.',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
