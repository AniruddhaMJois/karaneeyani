import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_layout.dart';
import 'daily_roadmap_screen.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late DatabaseService _dbService;
  final Set<String> _selectedTaskIds = {};
  final Set<String> _selectedGoalIds = {};

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
  }

  void _toggleTaskSelection(String id) {
    setState(() {
      if (_selectedTaskIds.contains(id)) {
        _selectedTaskIds.remove(id);
      } else {
        _selectedTaskIds.add(id);
      }
    });
  }

  void _toggleGoalSelection(String id) {
    setState(() {
      if (_selectedGoalIds.contains(id)) {
        _selectedGoalIds.remove(id);
      } else {
        _selectedGoalIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTaskIds.clear();
      _selectedGoalIds.clear();
    });
  }

  void _selectAllTasks(List<TaskModel> items) {
    setState(() {
      if (_selectedTaskIds.length == items.length) {
        _selectedTaskIds.clear();
      } else {
        _selectedTaskIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _selectAllGoals(List<GoalModel> items) {
    setState(() {
      if (_selectedGoalIds.length == items.length) {
        _selectedGoalIds.clear();
      } else {
        _selectedGoalIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _deleteSelected() {
    for (String id in _selectedTaskIds) {
      _dbService.deleteTaskPermanently(id);
    }
    for (String id in _selectedGoalIds) {
      _dbService.deleteGoalPermanently(id);
    }
    _clearSelection();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected items deleted')));
  }

  void _restoreSelected(List<TaskModel> tasks, List<GoalModel> goals) {
    for (String id in _selectedTaskIds) {
      final task = tasks.firstWhere((t) => t.id == id);
      _dbService.restoreTask(task);
    }
    for (String id in _selectedGoalIds) {
      final goal = goals.firstWhere((g) => g.id == id);
      _dbService.restoreGoal(goal);
    }
    _clearSelection();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected items restored')));
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isSelectionMode ? '${_selectedTaskIds.length + _selectedGoalIds.length} Selected' : 'Recycle Bin', style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) 
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => DailyRoadmapScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                },
              ),
          actions: [
            if (isSelectionMode) ...[
              // Assuming we only restore/select-all based on the active tab if needed, but since we are merging actions
              // It's a bit complex to select all for BOTH streams.
              // To keep it simple, we just have restore and delete.
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: 'Delete Selected',
                onPressed: _deleteSelected,
              ),
            ]
          ],
          bottom: const TabBar(
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Tasks', icon: Icon(Icons.task_alt)),
              Tab(text: 'Goals', icon: Icon(Icons.flag_outlined)),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Colors.red.shade900.withOpacity(0.1),
              ],
            ),
          ),
          child: TabBarView(
            children: [
              // TASKS TAB
              StreamBuilder<List<TaskModel>>(
                stream: _dbService.trashedTasks,
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? [];
                  return ResponsiveLayout(
                    mobileBody: _buildTasksBody(tasks, isDesktop: false),
                    desktopBody: _buildTasksBody(tasks, isDesktop: true),
                  );
                },
              ),
              // GOALS TAB
              StreamBuilder<List<GoalModel>>(
                stream: _dbService.trashedGoals,
                builder: (context, snapshot) {
                  final goals = snapshot.data ?? [];
                  return ResponsiveLayout(
                    mobileBody: _buildGoalsBody(goals, isDesktop: false),
                    desktopBody: _buildGoalsBody(goals, isDesktop: true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TASKS BUILDERS ---

  Widget _buildTasksBody(List<TaskModel> tasks, {required bool isDesktop}) {
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
        itemBuilder: (context, index) => _buildTaskCard(tasks[index]).animate().fade().scale(begin: const Offset(0.95, 0.95)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildTaskCard(tasks[index]),
      ).animate().fade().slideY(begin: 0.1),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final daysLeft = 5 - (DateTime.now().difference(task.deletedAt ?? DateTime.now()).inDays);
    final isSelected = _selectedTaskIds.contains(task.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleTaskSelection(task.id),
      onTap: () {
        if (isSelectionMode) _toggleTaskSelection(task.id);
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

  // --- GOALS BUILDERS ---

  Widget _buildGoalsBody(List<GoalModel> goals, {required bool isDesktop}) {
    if (goals.isEmpty) {
      return const Center(
        child: Text('Bin is empty.\nDeleted goals are kept here for 5 days.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
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
        itemCount: goals.length,
        itemBuilder: (context, index) => _buildGoalCard(goals[index]).animate().fade().scale(begin: const Offset(0.95, 0.95)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: goals.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildGoalCard(goals[index]),
      ).animate().fade().slideY(begin: 0.1),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final daysLeft = 5 - (DateTime.now().difference(goal.deletedAt ?? DateTime.now()).inDays);
    final isSelected = _selectedGoalIds.contains(goal.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleGoalSelection(goal.id),
      onTap: () {
        if (isSelectionMode) _toggleGoalSelection(goal.id);
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
            title: Text(goal.title, style: const TextStyle(color: Colors.white)),
            subtitle: Text('$daysLeft days left until auto-deletion', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            trailing: isSelectionMode ? null : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.white54),
                  tooltip: 'Restore',
                  onPressed: () => _dbService.restoreGoal(goal),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  tooltip: 'Delete Permanently',
                  onPressed: () => _dbService.deleteGoalPermanently(goal.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
