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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GoalCreationSheet(dbService: dbService, goalToEdit: goalToEdit),
      ),
    );
  }

  @override
  State<GoalCreationSheet> createState() => _GoalCreationSheetState();
}

class _GoalCreationSheetState extends State<GoalCreationSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _titleController.text = widget.goalToEdit!.title;
      _descController.text = widget.goalToEdit!.description;
      if (widget.goalToEdit!.selectedDates.isNotEmpty) {
        _selectedDates = List.from(widget.goalToEdit!.selectedDates);
      } else if (widget.goalToEdit!.endDate != null) {
        _selectedDates = [widget.goalToEdit!.endDate!];
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        if (!_selectedDates.any((d) => d.year == picked.year && d.month == picked.month && d.day == picked.day)) {
          _selectedDates.add(picked);
          _selectedDates.sort();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveGoal() {
    if (_titleController.text.trim().isEmpty) return;

    if (widget.goalToEdit == null) {
      final goal = GoalModel(
        id: '',
        userId: widget.dbService.userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        endDate: _selectedDates.isNotEmpty ? _selectedDates.last : null,
        selectedDates: _selectedDates,
        order: widget.goalToEdit?.order ?? -DateTime.now().millisecondsSinceEpoch,
      );
      widget.dbService.addGoal(goal);
    } else {
      widget.goalToEdit!.title = _titleController.text.trim();
      widget.goalToEdit!.description = _descController.text.trim();
      widget.goalToEdit!.endDate = _selectedDates.isNotEmpty ? _selectedDates.last : null;
      widget.goalToEdit!.selectedDates = _selectedDates;
      widget.dbService.updateGoal(widget.goalToEdit!);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.goalToEdit == null ? 'New Goal' : 'Edit Goal',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Goal Title',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          const Divider(color: Colors.white24),
          TextField(
            controller: _descController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Description (optional)',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._selectedDates.map((date) => Chip(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                label: Text(DateFormat('MMM d').format(date), style: const TextStyle(color: Colors.white)),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white70),
                onDeleted: () {
                  setState(() => _selectedDates.remove(date));
                },
              )),
              ActionChip(
                backgroundColor: Colors.white.withOpacity(0.05),
                avatar: const Icon(Icons.add, size: 16, color: Colors.white54),
                label: const Text('Add Date', style: TextStyle(color: Colors.white)),
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              widget.goalToEdit == null ? 'Create Goal' : 'Save Changes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
