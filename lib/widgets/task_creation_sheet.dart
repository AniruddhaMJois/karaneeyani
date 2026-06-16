import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class TaskCreationSheet extends StatefulWidget {
  final DatabaseService dbService;
  final TaskModel? taskToEdit;
  final String? predefinedGoalId;

  const TaskCreationSheet({super.key, required this.dbService, this.taskToEdit, this.predefinedGoalId});

  static void show(BuildContext context, DatabaseService dbService, {TaskModel? taskToEdit, String? predefinedGoalId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TaskCreationSheet(dbService: dbService, taskToEdit: taskToEdit, predefinedGoalId: predefinedGoalId),
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
  List<int> _repeatDays = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    _endDate = widget.taskToEdit?.endDate;
    _hasAlarm = widget.taskToEdit?.hasAlarm ?? false;
    _alarmTime = widget.taskToEdit?.alarmTime;
    _repeatDays = List.from(widget.taskToEdit?.repeatDays ?? []);
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
        goalId: widget.taskToEdit?.goalId ?? widget.predefinedGoalId,
        order: widget.taskToEdit?.order ?? -DateTime.now().millisecondsSinceEpoch,
        repeatDays: _repeatDays,
      );

      String finalTaskId = task.id;
      if (widget.taskToEdit == null) {
        finalTaskId = widget.dbService.addTask(task);
      } else {
        task.userId = widget.taskToEdit!.userId;
        widget.dbService.updateTask(task);
      }

      // Schedule Alarm
      if (_hasAlarm && _alarmTime != null) {
        final List<DateTime> alarmTimes = [];
        if (_repeatDays.isNotEmpty) {
          // Schedule for the next 28 days
          for (int i = 0; i < 28; i++) {
            final d = _alarmTime!.add(Duration(days: i));
            if (_repeatDays.contains(d.weekday) && d.isAfter(DateTime.now())) {
              alarmTimes.add(d);
            }
          }
        } else {
          if (_alarmTime!.isAfter(DateTime.now())) {
            alarmTimes.add(_alarmTime!);
          }
        }

        int alarmIndex = 0;
        for (final time in alarmTimes) {
          final alarmId = (finalTaskId.hashCode.abs() % 100000) * 100 + alarmIndex;
          alarmIndex++;
          
          final String bodyText = _descController.text.isNotEmpty 
              ? '${task.title}|||${_descController.text}' 
              : '${task.title}|||';
              
          final alarmSettings = AlarmSettings(
            id: alarmId,
            dateTime: time,
            assetAudioPath: NotificationService.localAlarmAudioPath ?? 'assets/alarm.wav', 
            volumeSettings: const VolumeSettings.fixed(),
            notificationSettings: NotificationSettings(
              title: 'Karaneeyaani',
              body: bodyText,
            ),
            loopAudio: true,
            vibrate: true,
            androidFullScreenIntent: false,
            payload: finalTaskId,
          );
          try {
            await Alarm.set(alarmSettings: alarmSettings);
            
            // Schedule 5-minute pre-notification
            await NotificationService.schedulePreAlarmNotification(
              id: alarmId + 10000,
              title: 'Karaneeyaani Upcoming Task',
              body: '${task.title} starts in 5 minutes!',
              scheduledTime: time.subtract(const Duration(minutes: 5)),
            );
          } catch (e) {
             debugPrint('Alarm scheduling failed for $time: $e');
          }
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
      child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              const Text('Repeat Alarm', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Everyday'),
                    selected: _repeatDays.length == 7,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _repeatDays = [1, 2, 3, 4, 5, 6, 7];
                        } else {
                          _repeatDays.clear();
                        }
                      });
                    },
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: _repeatDays.length == 7 ? Colors.white : Colors.white54),
                  ),
                  ...List.generate(7, (index) {
                    final dayMap = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F', 6: 'S', 7: 'S'};
                    final day = index + 1;
                    final isSelected = _repeatDays.contains(day);
                    return FilterChip(
                      label: Text(dayMap[day]!),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _repeatDays.add(day);
                          } else {
                            _repeatDays.remove(day);
                          }
                        });
                      },
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white54),
                    );
                  }),
                ],
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
      ),
    );
  }
}
