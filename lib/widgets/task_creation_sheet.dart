import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';

class TaskCreationSheet extends StatefulWidget {
  final DatabaseService dbService;
  final TaskModel? taskToEdit;

  const TaskCreationSheet({super.key, required this.dbService, this.taskToEdit});

  static void show(BuildContext context, DatabaseService dbService, {TaskModel? taskToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TaskCreationSheet(dbService: dbService, taskToEdit: taskToEdit),
      ),
    );
  }

  @override
  State<TaskCreationSheet> createState() => _TaskCreationSheetState();
}

class _TaskCreationSheetState extends State<TaskCreationSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _endDate;
  bool _hasAlarm = false;
  DateTime? _alarmTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    _endDate = widget.taskToEdit?.endDate;
    _hasAlarm = widget.taskToEdit?.hasAlarm ?? false;
    _alarmTime = widget.taskToEdit?.alarmTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final task = TaskModel(
        id: widget.taskToEdit?.id ?? '', 
        userId: '', // Set by dbService
        title: _titleController.text,
        description: _descController.text,
        endDate: _endDate,
        hasAlarm: _hasAlarm,
        alarmTime: _hasAlarm ? _alarmTime : null,
      );

      if (widget.taskToEdit == null) {
        await widget.dbService.addTask(task);
      } else {
        task.userId = widget.taskToEdit!.userId;
        await widget.dbService.updateTask(task);
      }

      // Schedule Offline Alarm
      if (_hasAlarm && _alarmTime != null && _alarmTime!.isAfter(DateTime.now())) {
        final alarmSettings = AlarmSettings(
          id: task.id.hashCode.abs() % 10000, // simple id gen
          dateTime: _alarmTime!,
          assetAudioPath: 'assets/alarm.mp3', // Note: needs asset setup, fallback to default sound usually works in package or we omit audio path if missing
          volumeSettings: const VolumeSettings.fixed(),
          notificationSettings: NotificationSettings(
            title: 'Karaneeyaani',
            body: 'Time to focus: ${task.title}',
          ),
          loopAudio: true,
          vibrate: true,
        );
        try {
          await Alarm.set(alarmSettings: alarmSettings);
        } catch (e) {
           debugPrint('Alarm scheduling failed: $e');
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        if (_hasAlarm && _alarmTime == null) {
          _alarmTime = DateTime(picked.year, picked.month, picked.day, 9, 0);
        }
      });
    }
  }

  Future<void> _pickAlarmTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime != null ? TimeOfDay.fromDateTime(_alarmTime!) : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        final dateBase = _endDate ?? DateTime.now();
        _alarmTime = DateTime(dateBase.year, dateBase.month, dateBase.day, picked.hour, picked.minute);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white10, width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: InputBorder.none,
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              autofocus: widget.taskToEdit == null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 2,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickEndDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            _endDate == null ? 'Set Date' : DateFormat('MMM d').format(_endDate!),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alarm', style: TextStyle(fontSize: 14)),
                    value: _hasAlarm,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) {
                      setState(() {
                        _hasAlarm = val;
                        if (val && _alarmTime == null) {
                          final dateBase = _endDate ?? DateTime.now();
                          _alarmTime = DateTime(dateBase.year, dateBase.month, dateBase.day, 9, 0);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_hasAlarm) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickAlarmTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.alarm, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        _alarmTime == null ? 'Select Time' : DateFormat('h:mm a').format(_alarmTime!),
                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Commit Intent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
