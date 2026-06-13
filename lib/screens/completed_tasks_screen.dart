import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';

class CompletedTasksScreen extends StatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskModel>>(
      stream: _dbService.completedTasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final isSelectionMode = _selectedTaskIds.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(isSelectionMode ? '${_selectedTaskIds.length} Selected' : 'Completed Intentions', style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: isSelectionMode ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) : null,
            actions: [
              if (isSelectionMode) ...[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(tasks),
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
                  Colors.green.shade900.withValues(alpha: 0.1),
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
      return const Center(child: Text('No completed tasks yet.', style: TextStyle(color: Colors.white54)));
    }

    if (isDesktop) {
      return GridView.builder(
        padding: const EdgeInsets.all(32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisExtent: 90,
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
    final isSelected = _selectedTaskIds.contains(task.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleSelection(task.id),
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(task.id);
        }
      },
      child: Card(
        elevation: isSelected ? 8 : 2,
        color: isSelected ? Colors.blue.withOpacity(0.15) : const Color(0xFF222222),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected ? const BorderSide(color: Colors.blueAccent, width: 2) : const BorderSide(color: Colors.white12, width: 1),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: ListTile(
            leading: isSelectionMode 
              ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.blueAccent : Colors.white54, size: 28)
              : IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
                  onPressed: () => _dbService.restoreTask(task),
                  tooltip: 'Untick to restore',
                ),
            title: Text(
              task.title, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: task.description.isNotEmpty 
              ? Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(task.description, style: const TextStyle(color: Colors.white60, fontSize: 14)),
                ) 
              : null,
            trailing: isSelectionMode ? null : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: 'Delete Permanently',
              onPressed: () {
                _dbService.deleteTaskPermanently(task.id);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task permanently deleted')));
              },
            ),
          ),
        ),
      ),
    );
  }
}
