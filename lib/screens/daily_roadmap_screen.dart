import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/glass_card.dart';

class DailyRoadmapScreen extends StatefulWidget {
  const DailyRoadmapScreen({super.key});

  @override
  State<DailyRoadmapScreen> createState() => _DailyRoadmapScreenState();
}

class _DailyRoadmapScreenState extends State<DailyRoadmapScreen> {
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
  }

  void _showTaskDoneToast(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Task "$title" successfully completed!', style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    const Text('Daily Roadmap', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    IconButton(
                      icon: const Icon(Icons.psychology_outlined),
                      tooltip: 'Deep Work Sanctuary',
                      onPressed: () {},
                    )
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<TaskModel>>(
                  stream: _dbService.activeTasks,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }

                    final tasks = snapshot.data ?? [];
                    if (tasks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 64, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            const Text('Your roadmap is clear.', style: TextStyle(color: Colors.white54, fontSize: 18)),
                          ],
                        ),
                      ).animate().fade(duration: 800.ms);
                    }

                    tasks.sort((a, b) {
                      if (a.endDate != null && b.endDate != null) return a.endDate!.compareTo(b.endDate!);
                      if (a.endDate != null) return -1;
                      if (b.endDate != null) return 1;
                      return 0;
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _buildTaskCard(task).animate().fade(delay: (100 * index).ms).slideX(begin: 0.1);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskCreationSheet.show(context, _dbService),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Commit Intent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 500.ms),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isOverdue = task.endDate != null && task.endDate!.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: GestureDetector(
            onTap: () {
              _showTaskDoneToast(task.title);
              _dbService.markTaskCompleted(task);
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 2),
              ),
            ),
          ),
          title: Text(task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
              if (task.endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.event, size: 14, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(task.endDate!),
                      style: TextStyle(fontSize: 12, color: isOverdue ? Colors.redAccent : Colors.white70),
                    ),
                    if (task.hasAlarm && task.alarmTime != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.alarm, size: 14, color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(DateFormat('h:mm a').format(task.alarmTime!), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ]
                  ],
                )
              ]
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: const Color(0xFF2A2A2A),
            onSelected: (value) {
              if (value == 'edit') {
                TaskCreationSheet.show(context, _dbService, taskToEdit: task);
              } else if (value == 'delete') {
                _dbService.softDeleteTask(task);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task moved to Bin (keeps for 5 days)')));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),
    );
  }
}
