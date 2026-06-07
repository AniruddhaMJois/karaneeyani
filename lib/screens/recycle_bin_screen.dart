import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Colors.red.shade900.withOpacity(0.1),
            ],
          ),
        ),
        child: StreamBuilder<List<TaskModel>>(
          stream: _dbService.trashedTasks,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final tasks = snapshot.data ?? [];

            if (tasks.isEmpty) {
              return const Center(
                child: Text('Bin is empty.\nDeleted tasks are kept here for 5 days.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                // Calculate days left
                final daysLeft = 5 - (DateTime.now().difference(task.deletedAt ?? DateTime.now()).inDays);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GlassCard(
                    child: ListTile(
                      title: Text(task.title, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('$daysLeft days left until auto-deletion', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      trailing: Row(
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
                ).animate().fade().slideY(begin: 0.1);
              },
            );
          },
        ),
      ),
    );
  }
}
