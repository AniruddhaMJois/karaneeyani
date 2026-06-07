import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';

class TaskCreationScreen extends StatefulWidget {
  final TaskModel? taskToEdit;

  const TaskCreationScreen({super.key, this.taskToEdit});

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final DatabaseService _dbService = DatabaseService();
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

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final task = TaskModel(
        id: widget.taskToEdit?.id ?? '', // DatabaseService uses add() which ignores ID for new tasks
        title: _titleController.text,
        description: _descController.text,
        endDate: _endDate,
        hasAlarm: _hasAlarm,
        alarmTime: _hasAlarm ? _alarmTime : null,
      );

      if (widget.taskToEdit == null) {
        _dbService.addTask(task);
      } else {
        _dbService.updateTask(task);
      }

      Navigator.pop(context);
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
        // Also default alarm time to same day if not set
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit == null ? 'New Intention' : 'Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTask,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'What needs to be done?',
                  border: InputBorder.none,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Title cannot be empty' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descController,
                maxLines: null,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                decoration: const InputDecoration(
                  hintText: 'Add description or micro-steps...',
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: Colors.white24, height: 40),
              
              // End Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.white54),
                title: Text(_endDate == null ? 'Set End Date' : DateFormat('MMM d, yyyy').format(_endDate!)),
                onTap: _pickEndDate,
              ),

              // Smart Alarm Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set Alarm'),
                subtitle: const Text('Create an implementation intention', style: TextStyle(fontSize: 12, color: Colors.white54)),
                value: _hasAlarm,
                activeColor: Theme.of(context).colorScheme.primary,
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

              // Alarm Time Picker (Animated visibility)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _hasAlarm ? 60 : 0,
                curve: Curves.easeInOut,
                child: ClipRect(
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 40),
                    leading: const Icon(Icons.access_time, color: Colors.white54),
                    title: Text(_alarmTime == null ? 'Select Time' : DateFormat('h:mm a').format(_alarmTime!)),
                    onTap: _pickAlarmTime,
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
