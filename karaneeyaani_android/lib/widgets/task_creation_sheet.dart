import 'package:flutter/foundation.dart';
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
  final DateTime? initialDate;

  const TaskCreationSheet({
    super.key,
    required this.dbService,
    this.taskToEdit,
    this.predefinedGoalId,
    this.initialDate,
  });

  static void show(
    BuildContext context,
    DatabaseService dbService, {
    TaskModel? taskToEdit,
    String? predefinedGoalId,
    DateTime? initialDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: TaskCreationSheet(
          dbService: dbService,
          taskToEdit: taskToEdit,
          predefinedGoalId: predefinedGoalId,
          initialDate: initialDate,
        ),
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
  late TextEditingController _progressController;
  DateTime? _endDate;
  bool _hasAlarm = false;
  DateTime? _alarmTime;
  List<int> _repeatDays = [];

  // Extension option: null, 1, 5, 10, or 'custom'
  String? _selectedExtensionPreset;
  List<DateTime> _customExtensionDates = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.taskToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.taskToEdit?.description ?? '');
    _progressController = TextEditingController(text: widget.taskToEdit?.progressStatus ?? '');
    // Default task date to today if creating new task
    _endDate = widget.taskToEdit?.endDate ?? widget.initialDate ?? DateTime.now();
    _hasAlarm = widget.taskToEdit?.hasAlarm ?? false;
    _alarmTime = widget.taskToEdit?.alarmTime;
    _repeatDays = List.from(widget.taskToEdit?.repeatDays ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  List<DateTime> _computeExtensionDates() {
    final base = _endDate ?? DateTime.now();
    final baseDay = DateTime(base.year, base.month, base.day);

    if (_selectedExtensionPreset == '1') {
      return [baseDay.add(const Duration(days: 1))];
    } else if (_selectedExtensionPreset == '5') {
      return List.generate(5, (i) => baseDay.add(Duration(days: i + 1)));
    } else if (_selectedExtensionPreset == '10') {
      return List.generate(10, (i) => baseDay.add(Duration(days: i + 1)));
    } else if (_selectedExtensionPreset == 'custom') {
      return _customExtensionDates;
    }
    return [];
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final task = TaskModel(
        id: widget.taskToEdit?.id ?? '',
        userId: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        progressStatus: _progressController.text.trim(),
        endDate: _endDate,
        hasAlarm: _hasAlarm,
        alarmTime: _hasAlarm ? _alarmTime : null,
        goalId: widget.taskToEdit?.goalId ?? widget.predefinedGoalId,
        order: widget.taskToEdit?.order ?? -DateTime.now().millisecondsSinceEpoch,
        repeatDays: _repeatDays,
        status: widget.taskToEdit?.status ?? TaskStatus.active,
        isDone: widget.taskToEdit?.isDone ?? false,
      );

      String finalTaskId = task.id;
      if (widget.taskToEdit == null) {
        finalTaskId = widget.dbService.addTask(task);
        final extensionDates = _computeExtensionDates();
        if (extensionDates.isNotEmpty) {
          widget.dbService.extendTask(task, extensionDates);
        }
      } else {
        task.userId = widget.taskToEdit!.userId;
        widget.dbService.updateTask(task);
      }

      // Schedule Alarm
      if (!kIsWeb && _hasAlarm && _alarmTime != null) {
        final List<DateTime> alarmTimes = [];
        if (_repeatDays.isNotEmpty) {
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
      firstDate: DateTime(2020),
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

  Future<void> _pickCustomExtensionRange() async {
    final initialRange = DateTimeRange(
      start: (_endDate ?? DateTime.now()).add(const Duration(days: 1)),
      end: (_endDate ?? DateTime.now()).add(const Duration(days: 3)),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      helpText: 'Select Extension Date Range',
    );

    if (picked != null) {
      final List<DateTime> dates = [];
      DateTime cur = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      while (!cur.isAfter(end)) {
        dates.add(cur);
        cur = cur.add(const Duration(days: 1));
      }

      setState(() {
        _selectedExtensionPreset = 'custom';
        _customExtensionDates = dates;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.taskToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
              const SizedBox(height: 20),

              // Title
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'What needs to be done?',
                  border: InputBorder.none,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Task title is required' : null,
                autofocus: widget.taskToEdit == null,
              ),
              const SizedBox(height: 6),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(fontSize: 15, color: Colors.white70),
                decoration: const InputDecoration(
                  hintText: 'Description notes (optional)',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 12),

              // Progress Status Field ("what has been done")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextFormField(
                  controller: _progressController,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    icon: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary, size: 22),
                    hintText: 'Status: What has been done so far...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Date & Alarm Row
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
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              _endDate == null ? 'Today' : DateFormat('MMM d, yyyy').format(_endDate!),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
                      activeTrackColor: theme.colorScheme.primary,
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
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickAlarmTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alarm, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          _alarmTime == null ? 'Select Time' : DateFormat('h:mm a').format(_alarmTime!),
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Repeat Alarm', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
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
                        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white54),
                      );
                    }),
                  ],
                ),
              ],

              // Task Extension Engine ("Extend This To") during creation
              if (!isEditing) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.more_time_rounded, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Extend This To',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('None'),
                      selected: _selectedExtensionPreset == null,
                      onSelected: (val) {
                        setState(() {
                          _selectedExtensionPreset = null;
                          _customExtensionDates.clear();
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                      labelStyle: TextStyle(color: _selectedExtensionPreset == null ? Colors.white : Colors.white60),
                    ),
                    ChoiceChip(
                      label: const Text('1 Day'),
                      selected: _selectedExtensionPreset == '1',
                      onSelected: (val) {
                        setState(() {
                          _selectedExtensionPreset = val ? '1' : null;
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                      labelStyle: TextStyle(color: _selectedExtensionPreset == '1' ? Colors.white : Colors.white60),
                    ),
                    ChoiceChip(
                      label: const Text('5 Days'),
                      selected: _selectedExtensionPreset == '5',
                      onSelected: (val) {
                        setState(() {
                          _selectedExtensionPreset = val ? '5' : null;
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                      labelStyle: TextStyle(color: _selectedExtensionPreset == '5' ? Colors.white : Colors.white60),
                    ),
                    ChoiceChip(
                      label: const Text('10 Days'),
                      selected: _selectedExtensionPreset == '10',
                      onSelected: (val) {
                        setState(() {
                          _selectedExtensionPreset = val ? '10' : null;
                        });
                      },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.35),
                      labelStyle: TextStyle(color: _selectedExtensionPreset == '10' ? Colors.white : Colors.white60),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(_selectedExtensionPreset == 'custom' && _customExtensionDates.isNotEmpty
                          ? '${_customExtensionDates.length} Days'
                          : 'Custom Range'),
                      backgroundColor: _selectedExtensionPreset == 'custom'
                          ? theme.colorScheme.primary.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.08),
                      onPressed: _pickCustomExtensionRange,
                      labelStyle: TextStyle(
                        color: _selectedExtensionPreset == 'custom' ? Colors.white : Colors.white60,
                        fontWeight: _selectedExtensionPreset == 'custom' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Commit Intent',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
