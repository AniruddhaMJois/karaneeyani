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
        title: const Text('Completed Intentions', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Colors.green.shade900.withOpacity(0.1),
            ],
          ),
        ),
        child: ResponsiveLayout(
          mobileBody: _buildBody(isDesktop: false),
          desktopBody: _buildBody(isDesktop: true),
        ),
      ),
    );
  }

  Widget _buildBody({required bool isDesktop}) {
    return StreamBuilder<List<TaskModel>>(
      stream: _dbService.completedTasks,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data ?? [];

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
      },
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return GlassCard(
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
        title: Text(task.title, style: const TextStyle(color: Colors.white38, decoration: TextDecoration.lineThrough)),
        trailing: IconButton(
          icon: const Icon(Icons.restore, color: Colors.white54),
          tooltip: 'Restore to Active',
          onPressed: () => _dbService.restoreTask(task),
        ),
      ),
    );
  }
}
