import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';

class GoalCreationSheet extends StatefulWidget {
  final DatabaseService dbService;
  final GoalModel? goalToEdit;

  const GoalCreationSheet({
    super.key,
    required this.dbService,
    this.goalToEdit,
  });

  static Future<void> show(BuildContext context, DatabaseService dbService, {GoalModel? goalToEdit}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => GoalCreationSheet(
        dbService: dbService,
        goalToEdit: goalToEdit,
      ),
    );
  }

  @override
  State<GoalCreationSheet> createState() => _GoalCreationSheetState();
}

class _GoalCreationSheetState extends State<GoalCreationSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goalToEdit?.title ?? '');
    _descController = TextEditingController(text: widget.goalToEdit?.description ?? '');
    _selectedEndDate = widget.goalToEdit?.endDate;
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
      initialDate: _selectedEndDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedEndDate = picked);
    }
  }

  void _saveGoal() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (widget.goalToEdit != null) {
      final goal = widget.goalToEdit!;
      goal.title = title;
      goal.description = _descController.text.trim();
      goal.endDate = _selectedEndDate;
      widget.dbService.updateGoal(goal);
    } else {
      final goal = GoalModel(
        id: '',
        userId: widget.dbService.userId,
        title: title,
        description: _descController.text.trim(),
        endDate: _selectedEndDate,
      );
      widget.dbService.addGoal(goal);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.goalToEdit != null;

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
                        isEditing ? 'Edit Goal / Project' : 'Create Goal / Project',
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
                      labelText: 'Goal Title',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Master Rust, Ship Version 2.0',
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
                      labelText: 'Vision & Scope',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'What defines success for this goal?',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Target Deadline Date
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event, size: 18, color: Colors.amberAccent),
                    label: Text(
                      _selectedEndDate != null
                          ? 'Deadline: ${DateFormat('MMM d, yyyy').format(_selectedEndDate!)}'
                          : 'Set Target Deadline Date',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: _saveGoal,
                      child: Text(
                        isEditing ? 'Save Goal Changes' : 'Establish Goal',
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
