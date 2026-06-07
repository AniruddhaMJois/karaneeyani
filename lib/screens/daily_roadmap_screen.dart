import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class DailyRoadmapScreen extends StatefulWidget {
  const DailyRoadmapScreen({super.key});

  @override
  State<DailyRoadmapScreen> createState() => _DailyRoadmapScreenState();
}

class _DailyRoadmapScreenState extends State<DailyRoadmapScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Roadmap', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Deep Work Sanctuary',
            onPressed: () {
              // TODO: Navigate to Deep Work
            },
          )
        ],
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _dbService.tasks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'Your roadmap is clear.\nTake a breath.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 18, fontStyle: FontStyle.italic),
              ),
            );
          }

          // Sort tasks: uncompleted first, then by end date
          tasks.sort((a, b) {
            if (a.isCompleted && !b.isCompleted) return 1;
            if (!a.isCompleted && b.isCompleted) return -1;
            if (a.endDate != null && b.endDate != null) return a.endDate!.compareTo(b.endDate!);
            if (a.endDate != null) return -1;
            if (b.endDate != null) return 1;
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(task);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open Task Creation
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isOverdue = task.endDate != null && task.endDate!.isBefore(DateTime.now()) && !task.isCompleted;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: task.isCompleted ? Colors.transparent : (isOverdue ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: GestureDetector(
          onTap: () => _dbService.toggleTaskCompletion(task),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isCompleted ? Theme.of(context).colorScheme.secondary : Colors.transparent,
              border: Border.all(
                color: task.isCompleted ? Theme.of(context).colorScheme.secondary : Colors.white54,
                width: 2,
              ),
            ),
            child: task.isCompleted ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.white38 : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
            if (task.endDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.event, size: 14, color: isOverdue ? Colors.redAccent : Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(task.endDate!),
                    style: TextStyle(fontSize: 12, color: isOverdue ? Colors.redAccent : Colors.white70),
                  ),
                  if (task.hasAlarm && task.alarmTime != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.alarm, size: 14, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(task.alarmTime!),
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
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
              // TODO: Navigate to Edit
            } else if (value == 'delete') {
              _dbService.deleteTask(task.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit', style: TextStyle(color: Colors.white)),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
