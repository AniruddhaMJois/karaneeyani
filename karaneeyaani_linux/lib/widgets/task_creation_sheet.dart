import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';

class TaskCreationSheet extends StatefulWidget {
  final DatabaseService dbService;
  final TaskModel? taskToEdit;
  final String? predefinedGoalId;
  final String? initialGoalId;
  final DateTime? initialDate;

  const TaskCreationSheet({
    super.key,
    required this.dbService,
    this.taskToEdit,
    this.predefinedGoalId,
    this.initialGoalId,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context,
    DatabaseService dbService, {
    TaskModel? taskToEdit,
    String? predefinedGoalId,
    String? initialGoalId,
    DateTime? initialDate,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => TaskCreationSheet(
        dbService: dbService,
        taskToEdit: taskToEdit,
        predefinedGoalId: predefinedGoalId,
        initialGoalId: initialGoalId,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<TaskCreationSheet> createState() => _TaskCreationSheetState();
}

class _TaskCreationSheetState extends State<TaskCreationSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _progressController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _hasAlarm = false;
  String? _selectedGoalId;

  // Extension feature
  int _extendDaysOption = 0; // 0 = None, 1 = 1 day, 5 = 5 days, 10 = 10 days, -1 = Custom Range
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    _progressController = TextEditingController(text: widget.taskToEdit?.progressNotes ?? '');
    _selectedDate = widget.taskToEdit?.endDate ?? widget.initialDate ?? DateTime.now();
    if (_selectedDate != null) {
      _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
    }
    _hasAlarm = widget.taskToEdit?.hasAlarm ?? false;
    _selectedGoalId = widget.taskToEdit?.goalId ?? widget.initialGoalId ?? widget.predefinedGoalId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialStart = _selectedDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: _customDateRange ??
          DateTimeRange(start: initialStart, end: initialStart.add(const Duration(days: 7))),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _extendDaysOption = -1;
        _selectedDate = picked.start;
      });
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    DateTime? finalEndDate = _selectedDate ?? DateTime.now();
    if (_selectedTime != null) {
      finalEndDate = DateTime(
        finalEndDate.year,
        finalEndDate.month,
        finalEndDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    DateTime? alarmTime = _hasAlarm ? finalEndDate : null;

    if (widget.taskToEdit != null) {
      final task = widget.taskToEdit!;
      task.title = title;
      task.description = _descController.text.trim();
      task.progressNotes = _progressController.text.trim();
      task.endDate = finalEndDate;
      task.hasAlarm = _hasAlarm;
      task.alarmTime = alarmTime;
      task.goalId = _selectedGoalId;
      widget.dbService.updateTask(task);

      if (_extendDaysOption > 0) {
        await widget.dbService.extendTask(task, _extendDaysOption);
      } else if (_extendDaysOption == -1 && _customDateRange != null) {
        await widget.dbService.extendTaskToDateRange(
          task,
          _customDateRange!.start,
          _customDateRange!.end,
        );
      }
    } else {
      final task = TaskModel(
        id: '',
        userId: widget.dbService.userId,
        title: title,
        description: _descController.text.trim(),
        progressNotes: _progressController.text.trim(),
        endDate: finalEndDate,
        hasAlarm: _hasAlarm,
        alarmTime: alarmTime,
        goalId: _selectedGoalId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.dbService.addTask(task);

      if (_extendDaysOption > 0) {
        await widget.dbService.extendTask(task, _extendDaysOption);
      } else if (_extendDaysOption == -1 && _customDateRange != null) {
        await widget.dbService.extendTaskToDateRange(
          task,
          _customDateRange!.start,
          _customDateRange!.end,
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final isEditing = widget.taskToEdit != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Material(
          color: const Color(0xFF18181E),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Task Intent' : "Commit Task to Today's Arena",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title Field
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'What is your core intent?',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Inline Progress Notes / Status field
                  TextField(
                    controller: _progressController,
                    style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Status / What has been done (Optional)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Read chapter 1, outline drafted...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2ECC71)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description Field
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Description / Notes',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'Add supplementary context or checklists...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Date & Time Selectors
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.white.withOpacity(0.15)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today, size: 18, color: Colors.white70),
                          label: Text(
                            _selectedDate != null ? DateFormat('MMM d, yyyy').format(_selectedDate!) : 'Today',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.white.withOpacity(0.15)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time, size: 18, color: Colors.white70),
                          label: Text(
                            _selectedTime != null ? _selectedTime!.format(context) : 'Time (Optional)',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // "Extend this to" feature
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.more_time_rounded, size: 16, color: Colors.cyanAccent),
                          const SizedBox(width: 6),
                          const Text(
                            'Extend this task to:',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_extendDaysOption != 0)
                            Text(
                              _extendDaysOption > 0
                                  ? '+ $_extendDaysOption Day(s)'
                                  : '${DateFormat('MMM d').format(_customDateRange!.start)} - ${DateFormat('MMM d').format(_customDateRange!.end)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildExtendPill(label: 'None', value: 0),
                          _buildExtendPill(label: '1 Day', value: 1),
                          _buildExtendPill(label: '5 Days', value: 5),
                          _buildExtendPill(label: '10 Days', value: 10),
                          ActionChip(
                            avatar: const Icon(Icons.date_range, size: 15, color: Colors.cyanAccent),
                            backgroundColor: _extendDaysOption == -1
                                ? Colors.cyanAccent.withOpacity(0.25)
                                : Colors.white.withOpacity(0.06),
                            side: BorderSide(
                              color: _extendDaysOption == -1 ? Colors.cyanAccent : Colors.white12,
                            ),
                            label: Text(
                              _customDateRange != null ? 'Custom Range' : 'Custom Range...',
                              style: TextStyle(
                                color: _extendDaysOption == -1 ? Colors.cyanAccent : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: _pickCustomRange,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Alarm Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alarm & Desktop Alert', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Play chime sound when due', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    activeColor: theme.secondary,
                    value: _hasAlarm,
                    onChanged: (val) {
                      setState(() {
                        _hasAlarm = val;
                        if (val && _selectedDate == null) {
                          _selectedDate = DateTime.now();
                          _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 30)));
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Goal Selector if not predefined
                  if (widget.predefinedGoalId == null)
                    StreamBuilder<List<GoalModel>>(
                      stream: widget.dbService.activeGoals,
                      builder: (context, snapshot) {
                        final goals = snapshot.data ?? [];
                        if (goals.isEmpty) return const SizedBox.shrink();

                        return DropdownButtonFormField<String?>(
                          value: _selectedGoalId,
                          dropdownColor: const Color(0xFF22222A),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Assign to Goal / Project',
                            labelStyle: const TextStyle(color: Colors.white60),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('No Goal (Standalone)')),
                            ...goals.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.title))),
                          ],
                          onChanged: (val) => setState(() => _selectedGoalId = val),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: _saveTask,
                      child: Text(
                        isEditing ? 'Save Changes' : "Commit to Today's Arena",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtendPill({required String label, required int value}) {
    final isSelected = _extendDaysOption == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.cyanAccent : Colors.white70,
      ),
      selected: isSelected,
      selectedColor: Colors.cyanAccent.withOpacity(0.25),
      backgroundColor: Colors.white.withOpacity(0.06),
      side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.white12),
      onSelected: (selected) {
        setState(() {
          _extendDaysOption = selected ? value : 0;
          if (_extendDaysOption != -1) {
            _customDateRange = null;
          }
        });
      },
    );
  }
}
