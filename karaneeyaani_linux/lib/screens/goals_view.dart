import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../models/task_model.dart';
import '../providers/navigation_provider.dart';
import '../services/database_service.dart';
import '../widgets/goal_creation_sheet.dart';

class GoalsView extends StatefulWidget {
  final DatabaseService dbService;

  const GoalsView({super.key, required this.dbService});

  @override
  State<GoalsView> createState() => _GoalsViewState();
}

class _GoalsViewState extends State<GoalsView> {
  final Set<String> _selectedGoalIds = {};
  String _searchQuery = '';
  String _selectedCategory = 'All';

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedGoalIds.contains(id)) {
        _selectedGoalIds.remove(id);
      } else {
        _selectedGoalIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedGoalIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return StreamBuilder<List<GoalModel>>(
      stream: widget.dbService.activeGoals,
      builder: (context, goalSnapshot) {
        final allGoals = goalSnapshot.data ?? [];

        return StreamBuilder<List<TaskModel>>(
          stream: widget.dbService.activeTasks,
          builder: (context, taskSnapshot) {
            final allTasks = taskSnapshot.data ?? [];

            // Extract unique categories
            final categories = ['All', ...allGoals.map((g) => g.category).where((c) => c.isNotEmpty).toSet()];

            // Filter goals
            final filteredGoals = allGoals.where((g) {
              final matchesQuery = _searchQuery.isEmpty ||
                  g.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  g.description.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchesCategory = _selectedCategory == 'All' || g.category == _selectedCategory;
              return matchesQuery && matchesCategory;
            }).toList();

            final isSelectionMode = _selectedGoalIds.isNotEmpty;

            return Column(
              children: [
                // Top Header / Action Bar
                _buildTopBar(context, filteredGoals, categories, isSelectionMode, theme),
                const Divider(color: Colors.white10, height: 1),

                // Goals List / Grid
                Expanded(
                  child: filteredGoals.isEmpty
                      ? _buildEmptyState(context, theme)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          itemCount: filteredGoals.length,
                          itemBuilder: (context, index) {
                            final goal = filteredGoals[index];
                            final linkedTasks = allTasks.where((t) => t.goalId == goal.id).toList();
                            return Padding(
                              key: ValueKey(goal.id),
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildGoalCard(
                                goal,
                                linkedTasks,
                                theme,
                                isSelectionMode,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    List<GoalModel> goals,
    List<String> categories,
    bool isSelectionMode,
    ColorScheme theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          if (isSelectionMode) ...[
            Text(
              '${_selectedGoalIds.length} goals selected',
              style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedGoalIds.addAll(goals.map((g) => g.id));
                });
              },
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Select All'),
            ),
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Deselect'),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {
                for (final id in _selectedGoalIds) {
                  widget.dbService.moveGoalToCompleted(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Moved selected goals to Completed Items')),
                );
              },
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: const Text('Move to Completed'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.tealAccent,
                side: const BorderSide(color: Colors.tealAccent),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final idsToDelete = Set<String>.from(_selectedGoalIds);
                for (final id in idsToDelete) {
                  widget.dbService.moveGoalToTrash(id);
                }
                _clearSelection();
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Moved ${idsToDelete.length} goals to Trash'),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () {
                        for (final id in idsToDelete) {
                          widget.dbService.restoreGoal(id);
                        }
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Move to Trash'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8)),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Goals & Projects',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${goals.length} active projects',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 32),
            // Search Input
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Search goals...',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Category Filter
            if (categories.length > 1) ...[
              DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: const Color(0xFF1E1E2C),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                underline: const SizedBox(),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(width: 16),
            ],
            // New Goal Button
            ElevatedButton.icon(
              onPressed: () => _openGoalCreator(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    GoalModel goal,
    List<TaskModel> linkedTasks,
    ColorScheme theme,
    bool isSelectionMode,
  ) {
    final completedTasks = linkedTasks.where((t) => t.isDone).length;
    final totalTasks = linkedTasks.length;
    final progress = totalTasks == 0 ? 0.0 : (completedTasks / totalTasks);
    final isSelected = _selectedGoalIds.contains(goal.id);

    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(goal.id);
        } else {
          // Open Goal Details
          context.read<NavigationProvider>().openGoalDetails(goal);
        }
      },
      onLongPress: () => _toggleSelection(goal.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primary.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primary : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleSelection(goal.id),
                  ),
                  const SizedBox(width: 8),
                ],
                // Icon Avatar
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_special_rounded, color: theme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                // Title and details
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
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (goal.category.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
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
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action Buttons: Complete Goal, Edit, Delete
                IconButton(
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  color: Colors.tealAccent,
                  tooltip: 'Move to Completed Goals',
                  onPressed: () {
                    widget.dbService.moveGoalToCompleted(goal.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Moved "${goal.title}" to Completed Goals')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                  tooltip: 'Edit Goal',
                  onPressed: () => _openGoalEditor(context, goal),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Move to Trash',
                  onPressed: () => _deleteGoal(goal),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Section
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        progress == 1.0 ? const Color(0xFF2ECC71) : theme.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    color: progress == 1.0 ? const Color(0xFF2ECC71) : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Sub-tasks summary and deadline
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  '$completedTasks of $totalTasks tasks done',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                if (goal.deadline != null) ...[
                  Icon(Icons.schedule_rounded, size: 14, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${DateFormat('MMM d, yyyy').format(goal.deadline!)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No Active Goals or Projects',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Break down large projects into manageable sub-tasks.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openGoalCreator(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _openGoalCreator(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => GoalCreationSheet(dbService: widget.dbService),
    );
  }

  void _openGoalEditor(BuildContext context, GoalModel goal) {
    showDialog(
      context: context,
      builder: (_) => GoalCreationSheet(
        dbService: widget.dbService,
        goalToEdit: goal,
      ),
    );
  }

  void _deleteGoal(GoalModel goal) {
    widget.dbService.moveGoalToTrash(goal.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved "${goal.title}" to Trash'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => widget.dbService.restoreGoal(goal.id),
        ),
      ),
    );
  }
}
