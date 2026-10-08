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
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _hasAlarm = false;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    _selectedDate = widget.taskToEdit?.endDate ?? widget.initialDate;
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

  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    DateTime? finalEndDate = _selectedDate;
    if (finalEndDate != null && _selectedTime != null) {
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
      task.endDate = finalEndDate;
      task.hasAlarm = _hasAlarm;
      task.alarmTime = alarmTime;
      task.goalId = _selectedGoalId;
      widget.dbService.updateTask(task);
    } else {
      final task = TaskModel(
        id: '',
        userId: widget.dbService.userId,
        title: title,
        description: _descController.text.trim(),
        endDate: finalEndDate,
        hasAlarm: _hasAlarm,
        alarmTime: alarmTime,
        goalId: _selectedGoalId,
      );
      widget.dbService.addTask(task);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final isEditing = widget.taskToEdit != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: const Color(0xFF18181E),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                        isEditing ? 'Edit Task Intent' : 'Commit New Task Intent',
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

                  // Description Field
                  TextField(
                    controller: _descController,
                    maxLines: 3,
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
                            _selectedDate != null ? DateFormat('MMM d, yyyy').format(_selectedDate!) : 'Pick Date',
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
                            _selectedTime != null ? _selectedTime!.format(context) : 'Pick Time',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
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
                        isEditing ? 'Save Changes' : 'Commit Intent',
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
}
