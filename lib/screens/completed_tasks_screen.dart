import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/responsive_layout.dart';
import 'daily_roadmap_screen.dart';

class CompletedTasksScreen extends StatefulWidget {
  const CompletedTasksScreen({super.key});

  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen> {
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

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isSelectionMode ? '${_selectedTaskIds.length + _selectedGoalIds.length} Selected' : 'Completed Items', style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection) 
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const DailyRoadmapScreen(),
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
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: 'Delete Selected',
                onPressed: _deleteSelected,
              ),
            ]
          ],
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.greenAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Tasks', icon: Icon(Icons.check_circle_outline)),
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
                Colors.green.shade900.withOpacity(0.1),
              ],
            ),
          ),
          child: TabBarView(
            children: [
              // TASKS TAB
              StreamBuilder<List<TaskModel>>(
                stream: _dbService.completedTasks,
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
                stream: _dbService.completedGoals,
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
    final isSelected = _selectedTaskIds.contains(task.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleTaskSelection(task.id),
      onTap: () {
        if (isSelectionMode) _toggleTaskSelection(task.id);
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
            title: Text(task.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            subtitle: task.description.isNotEmpty 
              ? Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(task.description, style: const TextStyle(color: Colors.white60, fontSize: 14))) 
              : null,
            trailing: isSelectionMode ? null : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: 'Delete Permanently',
              onPressed: () {
                _dbService.deleteTaskPermanently(task.id);
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- GOALS BUILDERS ---

  Widget _buildGoalsBody(List<GoalModel> goals, {required bool isDesktop}) {
    if (goals.isEmpty) {
      return const Center(child: Text('No completed goals yet.', style: TextStyle(color: Colors.white54)));
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
    final isSelected = _selectedGoalIds.contains(goal.id);
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;

    return GestureDetector(
      onLongPress: () => _toggleGoalSelection(goal.id),
      onTap: () {
        if (isSelectionMode) _toggleGoalSelection(goal.id);
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
                  icon: const Icon(Icons.flag, color: Colors.greenAccent, size: 28),
                  onPressed: () => _dbService.restoreGoal(goal),
                  tooltip: 'Restore Goal',
                ),
            title: Text(goal.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
            subtitle: goal.description.isNotEmpty 
              ? Padding(padding: const EdgeInsets.only(top: 6.0), child: Text(goal.description, style: const TextStyle(color: Colors.white60, fontSize: 14))) 
              : null,
            trailing: isSelectionMode ? null : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              tooltip: 'Delete Permanently',
              onPressed: () {
                _dbService.deleteGoalPermanently(goal.id);
              },
            ),
          ),
        ),
      ),
    );
  }
}
