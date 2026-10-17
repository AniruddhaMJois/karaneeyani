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

class _RecycleBinScreenState extends State<RecycleBinScreen> with SingleTickerProviderStateMixin {
  late DatabaseService _dbService;
  late TabController _tabController;
  final Set<String> _selectedTaskIds = {};
  final Set<String> _selectedGoalIds = {};

  List<TaskModel> _currentTasks = [];
  List<GoalModel> _currentGoals = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _toggleSelectAllCurrentTab() {
    setState(() {
      if (_tabController.index == 0) {
        if (_selectedTaskIds.length == _currentTasks.length) {
          _selectedTaskIds.clear();
        } else {
          _selectedTaskIds.addAll(_currentTasks.map((e) => e.id));
        }
      } else {
        if (_selectedGoalIds.length == _currentGoals.length) {
          _selectedGoalIds.clear();
        } else {
          _selectedGoalIds.addAll(_currentGoals.map((e) => e.id));
        }
      }
    });
  }

  Future<void> _restoreSelected() async {
    final count = _selectedTaskIds.length + _selectedGoalIds.length;
    if (count == 0) return;

    if (_selectedTaskIds.isNotEmpty) {
      await _dbService.restoreTrashedTasks(_selectedTaskIds);
    }
    if (_selectedGoalIds.isNotEmpty) {
      await _dbService.restoreTrashedGoals(_selectedGoalIds);
    }

    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count item(s) restored from Recycle Bin'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedTaskIds.length + _selectedGoalIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete $count selected item(s) from Recycle Bin? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_selectedTaskIds.isNotEmpty) {
        await _dbService.deleteTasksPermanently(_selectedTaskIds);
      }
      if (_selectedGoalIds.isNotEmpty) {
        await _dbService.deleteGoalsPermanently(_selectedGoalIds);
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count item(s) permanently deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _confirmRestoreAll() async {
    final isTasksTab = _tabController.index == 0;
    final count = isTasksTab ? _currentTasks.length : _currentGoals.length;
    final itemType = isTasksTab ? 'tasks' : 'goals';

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No deleted $itemType to restore'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Restore All Deleted $itemType?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Restore all $count deleted $itemType from Recycle Bin back to your active list?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (isTasksTab) {
        await _dbService.restoreTrashedTasks(_currentTasks.map((t) => t.id));
      } else {
        await _dbService.restoreTrashedGoals(_currentGoals.map((g) => g.id));
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All $count deleted $itemType restored'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _confirmEmptyBin() async {
    final isTasksTab = _tabController.index == 0;
    final count = isTasksTab ? _currentTasks.length : _currentGoals.length;
    final itemType = isTasksTab ? 'tasks' : 'goals';

    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recycle Bin has no $itemType to delete'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Empty Bin ($itemType)?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete all $count $itemType in Recycle Bin? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Bin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (isTasksTab) {
        await _dbService.deleteTasksPermanently(_currentTasks.map((t) => t.id));
      } else {
        await _dbService.deleteGoalsPermanently(_currentGoals.map((g) => g.id));
      }
      _clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recycle Bin emptied for $itemType ($count items erased)'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _selectedTaskIds.isNotEmpty || _selectedGoalIds.isNotEmpty;
    final totalSelected = _selectedTaskIds.length + _selectedGoalIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSelectionMode ? '$totalSelected Selected' : 'Recycle Bin',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              tooltip: 'Select All on Tab',
              onPressed: _toggleSelectAllCurrentTab,
            ),
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.blueAccent),
              tooltip: 'Restore Selected',
              onPressed: _restoreSelected,
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: 'Delete Selected Permanently',
              onPressed: _confirmDeleteSelected,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.greenAccent),
              tooltip: 'Restore All',
              onPressed: _confirmRestoreAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: 'Empty Bin',
              onPressed: _confirmEmptyBin,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.redAccent,
          labelColor: Colors.redAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
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
          controller: _tabController,
          children: [
            // TASKS TAB
            StreamBuilder<List<TaskModel>>(
              stream: _dbService.trashedTasks,
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                _currentTasks = tasks;
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
                _currentGoals = goals;
                return ResponsiveLayout(
                  mobileBody: _buildGoalsBody(goals, isDesktop: false),
                  desktopBody: _buildGoalsBody(goals, isDesktop: true),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- TASKS BUILDERS ---

  Widget _buildTasksBody(List<TaskModel> tasks, {required bool isDesktop}) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('Bin is empty.\nDeleted tasks are kept here for 5 days.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
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
                ? Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.redAccent : Colors.white54,
                    size: 28,
                  )
                : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
            title: Text(
              task.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
            ),
            subtitle: Text(
              '$daysLeft days left until auto-deletion',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            trailing: isSelectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: const Icon(Icons.restore, color: Colors.white70, size: 22),
                        tooltip: 'Restore Task',
                        onPressed: () {
                          _dbService.restoreTask(task);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${task.title}" restored from Bin'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                        tooltip: 'Delete Permanently',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: Text('Permanently delete "${task.title}"? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _dbService.deleteTaskPermanently(task.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${task.title}" permanently deleted'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          }
                        },
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
        child: Text('Bin is empty.\nDeleted goals are kept here for 5 days.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
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
                ? Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.redAccent : Colors.white54,
                    size: 28,
                  )
                : const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
            title: Text(
              goal.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
            ),
            subtitle: Text(
              '$daysLeft days left until auto-deletion',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            trailing: isSelectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: const Icon(Icons.restore, color: Colors.white70, size: 22),
                        tooltip: 'Restore Goal',
                        onPressed: () {
                          _dbService.restoreGoal(goal);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('"${goal.title}" restored from Bin'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                        tooltip: 'Delete Permanently',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              content: Text('Permanently delete "${goal.title}" and all its tasks? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            _dbService.deleteGoalPermanently(goal.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${goal.title}" permanently deleted'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
