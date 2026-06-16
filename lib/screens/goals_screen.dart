import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/goal_creation_sheet.dart';
import '../widgets/custom_drawer.dart';
import 'goal_details_screen.dart';
import '../models/task_model.dart';

class GoalsScreen extends StatefulWidget {
  final bool openGoalSheet;
  const GoalsScreen({super.key, this.openGoalSheet = false});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late DatabaseService _dbService;
  Set<String> _selectedGoals = {};

  void _toggleSelection(String goalId) {
    setState(() {
      if (_selectedGoals.contains(goalId)) {
        _selectedGoals.remove(goalId);
      } else {
        _selectedGoals.add(goalId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: authService.user!.uid);

    if (widget.openGoalSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoalCreationSheet.show(context, _dbService);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GoalModel>>(
      stream: _dbService.activeGoals,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final goals = snapshot.data ?? [];

        return Scaffold(
          drawer: const CustomDrawer(),
          appBar: AppBar(
            title: Text(
              _selectedGoals.isNotEmpty ? '${_selectedGoals.length} Selected' : 'Goals & Projects', 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: _selectedGoals.isNotEmpty 
              ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedGoals.clear())) 
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
            actions: _selectedGoals.isNotEmpty ? [
              IconButton(
                icon: const Icon(Icons.select_all, color: Colors.white),
                onPressed: () {
                  setState(() {
                    if (_selectedGoals.length == goals.length) {
                      _selectedGoals.clear();
                    } else {
                      _selectedGoals = goals.map((g) => g.id).toSet();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () {
                  for (final id in _selectedGoals) {
                    final g = goals.firstWhere((g) => g.id == id);
                    _dbService.softDeleteGoal(g);
                  }
                  setState(() => _selectedGoals.clear());
                },
              ),
            ] : null,
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
            ),
            child: goals.isEmpty ? const Center(
              child: Text(
                'No active goals. Create one to get started!',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ) : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  buildDefaultDragHandles: false,
                  itemCount: goals.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = goals.removeAt(oldIndex);
                    goals.insert(newIndex, item);
                    _dbService.updateGoalOrders(goals);
                  },
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return Padding(
                      key: ValueKey(goal.id),
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Dismissible(
                        key: Key('dismiss_${goal.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white, size: 30),
                        ),
                        onDismissed: (direction) {
                          _dbService.softDeleteGoal(goal);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${goal.title} moved to Recycle Bin')));
                        },
                        child: Card(
                          elevation: 4,
                          color: _selectedGoals.contains(goal.id) ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF222222),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: _selectedGoals.contains(goal.id) ? Colors.blueAccent : Colors.white12,
                              width: _selectedGoals.contains(goal.id) ? 2.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 16.0, right: 4.0),
                                  child: Icon(Icons.drag_handle, color: Colors.white54, size: 28),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onLongPress: () => _toggleSelection(goal.id),
                                  onTap: () {
                                    if (_selectedGoals.isNotEmpty) {
                                      _toggleSelection(goal.id);
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GoalDetailsScreen(goal: goal, dbService: _dbService),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20.0, top: 20.0, bottom: 20.0, left: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                goal.title,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                                              onPressed: () {
                                                GoalCreationSheet.show(context, _dbService, goalToEdit: goal);
                                              },
                                            ),
                                          ],
                                        ),
                                        if (goal.description.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            goal.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: Colors.white60, fontSize: 14),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                              if (goal.endDate != null) ...[
                                                Icon(Icons.event, size: 14, color: Theme.of(context).colorScheme.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  "${goal.endDate!.day}/${goal.endDate!.month}/${goal.endDate!.year}",
                                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 16),
                                              ],
                                              StreamBuilder<List<TaskModel>>(
                                                stream: _dbService.tasksForGoal(goal.id),
                                                builder: (context, taskSnapshot) {
                                                  final count = taskSnapshot.data?.where((t) => !t.isDone).length ?? 0;
                                                  return Row(
                                                    children: [
                                                      const Icon(Icons.check_box_outlined, size: 14, color: Colors.amberAccent),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$count active tasks',
                                                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                onPressed: () {
                                                  _dbService.markGoalCompleted(goal.id);
                                                },
                                                icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                                                label: const Text('Complete Goal', style: TextStyle(color: Colors.greenAccent)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => GoalCreationSheet.show(context, _dbService),
            backgroundColor: Theme.of(context).colorScheme.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
