import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';

class CompletedItemsView extends StatefulWidget {
  final DatabaseService dbService;

  const CompletedItemsView({super.key, required this.dbService});

  @override
  State<CompletedItemsView> createState() => _CompletedItemsViewState();
}

class _CompletedItemsViewState extends State<CompletedItemsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedTaskIds = {};
  final Set<String> _selectedGoalIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _clearTaskSelection() => setState(() => _selectedTaskIds.clear());
  void _clearGoalSelection() => setState(() => _selectedGoalIds.clear());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.completedTasks,
      builder: (context, taskSnapshot) {
        final completedTasks = taskSnapshot.data ?? [];

        return StreamBuilder<List<GoalModel>>(
          stream: widget.dbService.completedGoals,
          builder: (context, goalSnapshot) {
            final completedGoals = goalSnapshot.data ?? [];

            return Column(
              children: [
                // Top Tab Bar & Global Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  color: Colors.white.withOpacity(0.02),
                  child: Row(
                    children: [
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: const Color(0xFF2ECC71),
                        indicatorWeight: 3,
                        labelColor: const Color(0xFF2ECC71),
                        unselectedLabelColor: Colors.white60,
                        tabs: [
                          Tab(
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Tasks (${completedTasks.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              children: [
                                const Icon(Icons.flag_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Goals (${completedGoals.length})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tasks Tab
                      _buildTasksTab(context, completedTasks, theme),
                      // Goals Tab
                      _buildGoalsTab(context, completedGoals, theme),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= TASKS TAB =================

  Widget _buildTasksTab(BuildContext context, List<TaskModel> tasks, ColorScheme theme) {
    final hasSelection = _selectedTaskIds.isNotEmpty;

    return Column(
      children: [
        // Action Bar for Tasks Tab
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: Colors.black.withOpacity(0.1),
          child: Row(
            children: [
              if (hasSelection) ...[
                Text(
                  '${_selectedTaskIds.length} tasks selected',
                  style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 14),
                TextButton(
                  onPressed: () => setState(() => _selectedTaskIds.addAll(tasks.map((t) => t.id))),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: _clearTaskSelection,
                  child: const Text('Deselect'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await widget.dbService.restoreCompletedTasks(_selectedTaskIds);
                    _clearTaskSelection();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restored selected tasks to active list')),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restore Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteTasksPermanently(context, _selectedTaskIds),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Permanently'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                Text(
                  '${tasks.length} Completed Tasks',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (tasks.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.dbService.restoreCompletedTasks(tasks.map((t) => t.id));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restored all tasks to active list')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_page_rounded, size: 16),
                    label: const Text('Restore All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                      side: const BorderSide(color: Color(0xFF2ECC71)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteTasksPermanently(context, tasks.map((t) => t.id).toSet()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: const Text('Delete All Permanently'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // Tasks List
        Expanded(
          child: tasks.isEmpty
              ? _buildEmptyState('No Completed Tasks', 'Tasks marked as completed will be stored here.', Icons.task_alt_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final isSelected = _selectedTaskIds.contains(task.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2ECC71).withOpacity(0.12)
                            : const Color(0xFF0D2818).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2ECC71) : const Color(0xFF2ECC71).withOpacity(0.3),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2ECC71),
                            checkColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedTaskIds.add(task.id);
                                } else {
                                  _selectedTaskIds.remove(task.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: const TextStyle(
                                    color: Color(0xFF2ECC71),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    task.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF2ECC71).withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check, size: 12, color: Colors.white38),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed on ${DateFormat('MMM d, yyyy h:mm a').format(task.updatedAt ?? DateTime.now())}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Restore Button
                          IconButton(
                            icon: const Icon(Icons.restore_rounded, color: Color(0xFF2ECC71), size: 20),
                            tooltip: 'Restore Task to Active',
                            onPressed: () {
                              widget.dbService.restoreCompletedTaskById(task.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restored "${task.title}" to active tasks')),
                              );
                            },
                          ),
                          // Permanent Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Permanently Delete',
                            onPressed: () => _confirmDeleteTasksPermanently(context, {task.id}),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= GOALS TAB =================

  Widget _buildGoalsTab(BuildContext context, List<GoalModel> goals, ColorScheme theme) {
    final hasSelection = _selectedGoalIds.isNotEmpty;

    return Column(
      children: [
        // Action Bar for Goals Tab
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: Colors.black.withOpacity(0.1),
          child: Row(
            children: [
              if (hasSelection) ...[
                Text(
                  '${_selectedGoalIds.length} goals selected',
                  style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 14),
                TextButton(
                  onPressed: () => setState(() => _selectedGoalIds.addAll(goals.map((g) => g.id))),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: _clearGoalSelection,
                  child: const Text('Deselect'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    await widget.dbService.restoreCompletedGoals(_selectedGoalIds);
                    _clearGoalSelection();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restored selected goals to active list')),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restore Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _confirmDeleteGoalsPermanently(context, _selectedGoalIds),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Permanently'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                Text(
                  '${goals.length} Completed Goals',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (goals.isNotEmpty) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      await widget.dbService.restoreCompletedGoals(goals.map((g) => g.id));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restored all goals to active list')),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_page_rounded, size: 16),
                    label: const Text('Restore All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                      side: const BorderSide(color: Color(0xFF2ECC71)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDeleteGoalsPermanently(context, goals.map((g) => g.id).toSet()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 16),
                    label: const Text('Delete All Permanently'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // Goals List
        Expanded(
          child: goals.isEmpty
              ? _buildEmptyState('No Completed Goals', 'Finished goals will appear here.', Icons.flag_circle_rounded)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final isSelected = _selectedGoalIds.contains(goal.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2ECC71).withOpacity(0.12)
                            : const Color(0xFF0D2818).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2ECC71) : const Color(0xFF2ECC71).withOpacity(0.3),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF2ECC71),
                            checkColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedGoalIds.add(goal.id);
                                } else {
                                  _selectedGoalIds.remove(goal.id);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        goal.title,
                                        style: const TextStyle(
                                          color: Color(0xFF2ECC71),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (goal.category.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          goal.category,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ),
                                  ],
                                ),
                                if (goal.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    goal.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF2ECC71).withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.check, size: 12, color: Colors.white38),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Completed on ${DateFormat('MMM d, yyyy').format(goal.updatedAt ?? DateTime.now())}',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Restore Button
                          IconButton(
                            icon: const Icon(Icons.restore_rounded, color: Color(0xFF2ECC71), size: 20),
                            tooltip: 'Restore Goal to Active',
                            onPressed: () {
                              widget.dbService.restoreCompletedGoalById(goal.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restored "${goal.title}" to active goals')),
                              );
                            },
                          ),
                          // Permanent Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Permanently Delete',
                            onPressed: () => _confirmDeleteGoalsPermanently(context, {goal.id}),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTasksPermanently(BuildContext context, Set<String> ids) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permanently Delete Tasks?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete ${ids.length} task(s)? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.dbService.deleteTasksPermanently(ids);
              _clearTaskSelection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Permanently deleted ${ids.length} task(s)')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGoalsPermanently(BuildContext context, Set<String> ids) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permanently Delete Goals?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete ${ids.length} goal(s) and all their tasks? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.dbService.deleteGoalsPermanently(ids);
              _clearGoalSelection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Permanently deleted ${ids.length} goal(s)')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
