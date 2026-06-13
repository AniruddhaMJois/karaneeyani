import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _titleController.text = widget.goalToEdit!.title;
      _descController.text = widget.goalToEdit!.description;
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
      );
      widget.dbService.addGoal(goal);
    } else {
      widget.goalToEdit!.title = _titleController.text.trim();
      widget.goalToEdit!.description = _descController.text.trim();
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
