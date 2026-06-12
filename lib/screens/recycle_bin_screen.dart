import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late DatabaseService _dbService;
  final Set<String> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
  }

  void _toggleSelection(String taskId) {
    setState(() {
      if (_selectedTaskIds.contains(taskId)) {
        _selectedTaskIds.remove(taskId);
      } else {
        _selectedTaskIds.add(taskId);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedTaskIds.clear());
  }

  void _selectAll(List<TaskModel> currentTasks) {
    setState(() {
      if (_selectedTaskIds.length == currentTasks.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds.addAll(currentTasks.map((t) => t.id));
      }
    });
  }

  void _deleteSelected() {
    for (String id in _selectedTaskIds) {
      _dbService.deleteTaskPermanently(id);
    }
    _clearSelection();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected tasks deleted')));
  }

  void _restoreSelected(List<TaskModel> tasks) {
    for (String id in _selectedTaskIds) {
      final task = tasks.firstWhere((t) => t.id == id);
      _dbService.restoreTask(task);
    }
    _clearSelection();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected tasks restored')));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _dbService.trashedTasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final isSelectionMode = _selectedTaskIds.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(isSelectionMode ? '${_selectedTaskIds.length} Selected' : 'Recycle Bin', style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) : null,
            actions: [
              if (isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(tasks),
                ),
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.greenAccent),
                  tooltip: 'Restore Selected',
                  onPressed: () => _restoreSelected(tasks),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Delete Selected',
                  onPressed: _deleteSelected,
                ),
              ]
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Colors.red.shade900.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: ResponsiveLayout(
              mobileBody: _buildBody(tasks, isDesktop: false),
              desktopBody: _buildBody(tasks, isDesktop: true),
            ),
          ),
        );
      }
    );
  }

  Widget _buildBody(List<TaskModel> tasks, {required bool isDesktop}) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('Bin is empty.\nDeleted tasks are kept here for 5 days.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
      );
    }

    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 100,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return _buildTaskCard(tasks[index]).animate().fade().scale(begin: const Offset(0.95, 0.95));
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildTaskCard(tasks[index]),
        ).animate().fade().slideY(begin: 0.1);
      },
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final daysLeft = 5 - (DateTime.now().difference(task.deletedAt ?? DateTime.now()).inDays);
    final isSelected = _selectedTaskIds.contains(task.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleSelection(task.id),
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(task.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.redAccent, width: 2) : null,
        ),
        child: GlassCard(
          child: ListTile(
            leading: isSelectionMode 
              ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.redAccent : Colors.white54)
              : null,
            title: Text(task.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text('$daysLeft days left until auto-deletion', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            trailing: isSelectionMode ? null : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.white54),
                  tooltip: 'Restore',
                  onPressed: () => _dbService.restoreTask(task),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  tooltip: 'Delete Permanently',
                  onPressed: () => _dbService.deleteTaskPermanently(task.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
