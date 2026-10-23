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

  void _showExtendDialog(TaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => _TaskExtendDialog(
        task: task,
        dbService: widget.dbService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.activeTasks,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final filteredTasks = allTasks.where((t) {
          if (_searchQuery.isEmpty) return true;
          return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.progressNotes.toLowerCase().contains(_searchQuery.toLowerCase());
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
            // Top Action Bar ("Today's Arena" Landing)
            _buildTopBar(context, sortedTasks, isSelectionMode, theme, now),
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
                          padding: const EdgeInsets.only(bottom: 14),
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

  Widget _buildTopBar(
    BuildContext context,
    List<TaskModel> tasks,
    bool isSelectionMode,
    ColorScheme theme,
    DateTime now,
  ) {
    final todayFormatted = DateFormat('EEEE, MMMM d, yyyy').format(now);

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
              icon: const Icon(Icons.archive_outlined, color: Colors.greenAccent),
              tooltip: 'Move Selected to Completed',
              onPressed: () {
                for (final id in _selectedTaskIds) {
                  widget.dbService.moveToCompleted(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selected tasks moved to Completed Items'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Today's Arena",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.primary.withOpacity(0.4)),
                      ),
                      child: Text(
                        todayFormatted,
                        style: TextStyle(color: theme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
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
              onPressed: () => TaskCreationSheet.show(
                context,
                widget.dbService,
                initialDate: DateTime.now(),
              ),
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
    final bool isExtended = (task.seriesId != null && task.seriesId!.isNotEmpty) || (task.extendedDays ?? 0) > 1;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onLongPress: () => _toggleSelection(task.id),
      onTap: isSelectionMode ? () => _toggleSelection(task.id) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.18)
              : isDone
                  ? const Color(0xFF0D2818).withOpacity(0.40)
                  : const Color(0xFF16161D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : isDone
                    ? const Color(0xFF2ECC71).withOpacity(0.5)
                    : isOverdue
                        ? Colors.redAccent.withOpacity(0.5)
                        : Colors.white.withOpacity(0.08),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Drag Handle / Checkbox, Title, Badges, Trailing Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Checkbox(
                      value: isSelected,
                      activeColor: Colors.blueAccent,
                      onChanged: (_) => _toggleSelection(task.id),
                    ),
                  )
                else
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.drag_indicator, color: Colors.white38, size: 20),
                    ),
                  ),

                // Title and Extension Badge
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDone ? const Color(0xFF2ECC71) : Colors.white,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isExtended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.more_time_rounded, size: 12, color: Colors.cyanAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Extended for ${task.extendedDays ?? 1} days',
                                style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing actions: Extend Icon, Edit, Delete
                if (!isSelectionMode) ...[
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.more_time_rounded, color: Colors.cyanAccent, size: 20),
                    tooltip: 'Extend this to...',
                    onPressed: () => _showExtendDialog(task),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 19),
                    tooltip: 'Edit Task',
                    onPressed: () => TaskCreationSheet.show(context, widget.dbService, taskToEdit: task),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
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
              ],
            ),

            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  task.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],

            // Inline Editable Status / Progress field ("what has been done")
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: _InlineProgressNotesField(
                task: task,
                onSaved: (val) {
                  widget.dbService.updateTaskProgressNotes(task.id, val);
                },
              ),
            ),

            const SizedBox(height: 10),

            // Dedicated Green "Completed" Button below progress notes
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Row(
                children: [
                  _buildCompletedButton(task, isDone),
                  const SizedBox(width: 12),
                  if (task.endDate != null) ...[
                    Icon(Icons.event, size: 13, color: isOverdue ? Colors.redAccent : Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.endDate!),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOverdue ? Colors.redAccent : Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (task.hasAlarm && task.alarmTime != null) ...[
                    Icon(Icons.alarm, size: 13, color: theme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(task.alarmTime!),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.secondary),
                    ),
                  ],
                  const Spacer(),
                  if (isDone)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2ECC71),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.outbox_rounded, size: 16),
                      label: const Text('Move to Completed Items', style: TextStyle(fontSize: 12)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedButton(TaskModel task, bool isDone) {
    if (isDone) {
      // Solid bright green button when completed
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2ECC71),
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.black),
        label: const Text(
          'Completed',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
        ),
        onPressed: () {
          widget.dbService.toggleTaskDone(task.id, false);
        },
      );
    } else {
      // Uncompleted button
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.radio_button_unchecked_rounded, size: 18, color: Colors.white60),
        label: const Text(
          'Mark as Completed',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70),
        ),
        onPressed: () {
          widget.dbService.toggleTaskDone(task.id, true);
        },
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 64, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 16),
          const Text(
            "Today's Arena is Clear!",
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Commit Intent" above to add new actions for today.',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Inline editable status / progress notes field
class _InlineProgressNotesField extends StatefulWidget {
  final TaskModel task;
  final ValueChanged<String> onSaved;

  const _InlineProgressNotesField({required this.task, required this.onSaved});

  @override
  State<_InlineProgressNotesField> createState() => _InlineProgressNotesFieldState();
}

class _InlineProgressNotesFieldState extends State<_InlineProgressNotesField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.task.progressNotes);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _save();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _InlineProgressNotesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.task.progressNotes != _controller.text) {
      _controller.text = widget.task.progressNotes;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    _isEditing = false;
    final val = _controller.text.trim();
    widget.onSaved(val);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _focusNode.hasFocus ? const Color(0xFF2ECC71) : Colors.white.withOpacity(0.08),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2ECC71)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Status: record what has been done...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onTap: () => setState(() => _isEditing = true),
              onSubmitted: (_) => _save(),
            ),
          ),
          if (hasText && _isEditing)
            IconButton(
              icon: const Icon(Icons.check, size: 16, color: Color(0xFF2ECC71)),
              tooltip: 'Save Progress Note',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: _save,
            ),
        ],
      ),
    );
  }
}

/// "Extend this to" Dialog for Existing Tasks
class _TaskExtendDialog extends StatefulWidget {
  final TaskModel task;
  final DatabaseService dbService;

  const _TaskExtendDialog({required this.task, required this.dbService});

  @override
  State<_TaskExtendDialog> createState() => _TaskExtendDialogState();
}

class _TaskExtendDialogState extends State<_TaskExtendDialog> {
  int _selectedPreset = 5; // default 5 days
  DateTimeRange? _customRange;
  bool _isLoading = false;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = widget.task.endDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _customRange ?? DateTimeRange(start: start, end: start.add(const Duration(days: 7))),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedPreset = -1;
      });
    }
  }

  Future<void> _submitExtend() async {
    setState(() => _isLoading = true);

    if (_selectedPreset > 0) {
      await widget.dbService.extendTask(widget.task, _selectedPreset);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extended "${widget.task.title}" for $_selectedPreset days across Calendar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (_selectedPreset == -1 && _customRange != null) {
      await widget.dbService.extendTaskToDateRange(
        widget.task,
        _customRange!.start,
        _customRange!.end,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extended "${widget.task.title}" across custom range'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.more_time_rounded, color: Colors.cyanAccent),
          SizedBox(width: 10),
          Text('Extend Task', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extend "${widget.task.title}" to future dates. Duplicated instances share title and progress notes, but each day maintains an independent "Completed" state.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Duration:',
              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _buildPresetChip('1 Day', 1),
                _buildPresetChip('5 Days', 5),
                _buildPresetChip('10 Days', 10),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 14, color: Colors.cyanAccent),
                  label: Text(
                    _customRange != null
                        ? '${DateFormat('MMM d').format(_customRange!.start)} - ${DateFormat('MMM d').format(_customRange!.end)}'
                        : 'Custom Range...',
                    style: TextStyle(
                      color: _selectedPreset == -1 ? Colors.cyanAccent : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _selectedPreset == -1 ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                  side: BorderSide(color: _selectedPreset == -1 ? Colors.cyanAccent : Colors.white12),
                  onPressed: _pickRange,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submitExtend,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Confirm Extension', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, int days) {
    final isSelected = _selectedPreset == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.cyanAccent.withOpacity(0.25),
      backgroundColor: Colors.white.withOpacity(0.06),
      side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.white12),
      labelStyle: TextStyle(
        color: isSelected ? Colors.cyanAccent : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedPreset = days;
            _customRange = null;
          });
        }
      },
    );
  }
}
