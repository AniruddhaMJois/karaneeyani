import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/task_creation_sheet.dart';
import 'goal_details_screen.dart';
import '../services/auth_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DatabaseService _dbService;
  DateTime _selectedDate = DateTime.now();
  late ScrollController _scrollController;
  final int _daysRange = 365;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context, listen: false);
    _dbService = DatabaseService(userId: auth.user!.uid);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    if (_scrollController.hasClients) {
      double offset = _daysRange * 68.0 - (MediaQuery.of(context).size.width / 2) + 34.0;
      _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Stream<Map<String, dynamic>> _getCalendarData() {
    return Rx.combineLatest2(
      _dbService.allActiveTasks, 
      _dbService.activeGoals,
      (List<TaskModel> tasks, List<GoalModel> goals) {
        return {
          'tasks': tasks,
          'goals': goals,
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: const CustomDrawer(),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _getCalendarData(),
        builder: (context, snapshot) {
          final tasks = (snapshot.data?['tasks'] as List<TaskModel>?) ?? [];
          final goals = (snapshot.data?['goals'] as List<GoalModel>?) ?? [];

          Map<DateTime, int> taskCounts = {};
          Map<DateTime, int> goalCounts = {};

          for (var t in tasks) {
            if (t.endDate != null) {
              final d = DateTime(t.endDate!.year, t.endDate!.month, t.endDate!.day);
              taskCounts[d] = (taskCounts[d] ?? 0) + 1;
            }
          }
          for (var g in goals) {
            for (var gd in g.selectedDates) {
              final d = DateTime(gd.year, gd.month, gd.day);
              goalCounts[d] = (goalCounts[d] ?? 0) + 1;
            }
            if (g.selectedDates.isEmpty && g.endDate != null) {
              final d = DateTime(g.endDate!.year, g.endDate!.month, g.endDate!.day);
              goalCounts[d] = (goalCounts[d] ?? 0) + 1;
            }
          }

          final selectedDateTasks = tasks.where((t) => t.endDate != null && _isSameDay(t.endDate!, _selectedDate)).toList();
          final selectedDateGoals = goals.where((g) {
            if (g.selectedDates.isNotEmpty) {
              return g.selectedDates.any((d) => _isSameDay(d, _selectedDate));
            }
            return g.endDate != null && _isSameDay(g.endDate!, _selectedDate);
          }).toList();

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                _buildCalendarRibbon(taskCounts, goalCounts),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: _buildItemsList(selectedDateTasks, selectedDateGoals, isDesktop),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCalendarRibbon(Map<DateTime, int> taskCounts, Map<DateTime, int> goalCounts) {
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: _daysRange));

    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _daysRange * 2 + 1,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, today);
          
          final dateKey = DateTime(date.year, date.month, date.day);
          final tCount = taskCounts[dateKey] ?? 0;
          final gCount = goalCounts[dateKey] ?? 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3) 
                    : (isToday ? Colors.white.withValues(alpha: 0.1) : Colors.transparent),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.white : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tCount > 0)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        ),
                      if (gCount > 0)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemsList(List<TaskModel> tasks, List<GoalModel> goals, bool isDesktop) {
    if (tasks.isEmpty && goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            const Text('Nothing scheduled for this day.', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    Widget list = ListView(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 16),
      children: [
        if (goals.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
            child: Text('Goals', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...goals.map((g) => _buildGoalCard(g)),
          const SizedBox(height: 16),
        ],
        if (tasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
            child: Text('Tasks', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...tasks.map((t) => _buildTaskCard(t)),
        ],
      ],
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: list,
        ),
      );
    }

    return list;
  }

  Widget _buildGoalCard(GoalModel goal) {
    return Card(
      color: const Color(0xFF222222),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.flag, color: Colors.amberAccent),
        title: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: goal.description.isNotEmpty 
            ? Text(goal.description, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailsScreen(goal: goal, dbService: _dbService),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Card(
      color: const Color(0xFF222222),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: GestureDetector(
          onTap: () {
            task.isDone = !task.isDone;
            _dbService.updateTask(task);
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.isDone ? Colors.green : Colors.transparent,
              border: Border.all(color: task.isDone ? Colors.green : Colors.white54, width: 2),
            ),
            child: task.isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: task.isDone ? Colors.white54 : Colors.white,
          ),
        ),
        subtitle: task.goalId != null
            ? const Text('Inside a Goal', style: TextStyle(color: Colors.blueAccent, fontSize: 12))
            : null,
        onTap: () {
          TaskCreationSheet.show(context, _dbService, taskToEdit: task);
        },
      ),
    );
  }
}
