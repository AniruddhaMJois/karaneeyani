import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import '../services/database_service.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/goal_creation_sheet.dart';

class CalendarView extends StatefulWidget {
  final DatabaseService dbService;

  const CalendarView({super.key, required this.dbService});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _selectedDate;
  late final ScrollController _ribbonController;
  final List<DateTime> _dates = [];
  final int _pastDays = 30;
  final int _futureDays = 335;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _ribbonController = ScrollController();

    // Generate dates: 30 days before today up to 335 days ahead
    final start = _selectedDate.subtract(Duration(days: _pastDays));
    for (int i = 0; i <= _pastDays + _futureDays; i++) {
      _dates.add(DateTime(start.year, start.month, start.day).add(Duration(days: i)));
    }

    // Scroll to today after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDate, animate: false);
    });
  }

  @override
  void dispose() {
    _ribbonController.dispose();
    super.dispose();
  }

  void _scrollToDate(DateTime target, {bool animate = true}) {
    final index = _dates.indexWhere(
      (d) => d.year == target.year && d.month == target.month && d.day == target.day,
    );
    if (index != -1 && _ribbonController.hasClients) {
      final offset = (index * 76.0) - (MediaQuery.of(context).size.width / 2) + 120;
      final clampedOffset = offset.clamp(0.0, _ribbonController.position.maxScrollExtent);
      if (animate) {
        _ribbonController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _ribbonController.jumpTo(clampedOffset);
      }
    }
  }

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return StreamBuilder<List<TaskModel>>(
      stream: widget.dbService.activeTasks,
      builder: (context, taskSnapshot) {
        final allTasks = taskSnapshot.data ?? [];

        return StreamBuilder<List<GoalModel>>(
          stream: widget.dbService.activeGoals,
          builder: (context, goalSnapshot) {
            final allGoals = goalSnapshot.data ?? [];

            // Filter for selected date
            final dayTasks = allTasks.where((t) => _isSameDay(t.scheduledDate, _selectedDate)).toList();
            // Sort: incomplete first, completed tasks sit down at bottom
            dayTasks.sort((a, b) {
              if (a.isDone && !b.isDone) return 1;
              if (!a.isDone && b.isDone) return -1;
              return a.order.compareTo(b.order);
            });

            final dayGoals = allGoals.where((g) => _isSameDay(g.deadline, _selectedDate)).toList();

            return Column(
              children: [
                // Ribbon Top Header
                _buildHeader(context, theme, today),
                // Horizontal 365-Day Ribbon
                _buildDateRibbon(theme, allTasks, allGoals),
                const Divider(color: Colors.white10, height: 1),

                // Selected Day Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: CustomScrollView(
                      slivers: [
                        // Scheduled Goals Section
                        if (dayGoals.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.flag_rounded, size: 18, color: theme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'GOALS DUE TODAY (${dayGoals.length})',
                                    style: TextStyle(
                                      color: theme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildGoalCard(dayGoals[index], allTasks, theme),
                              childCount: dayGoals.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],

                        // Tasks Section Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 18, color: theme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'SCHEDULED TASKS (${dayTasks.length})',
                                  style: TextStyle(
                                    color: theme.secondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _openTaskCreator(context, _selectedDate),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Tasks List or Empty State
                        if (dayTasks.isEmpty && dayGoals.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(context, theme),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTaskCard(dayTasks[index], theme),
                              ),
                              childCount: dayTasks.length,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme theme, DateTime today) {
    final isToday = _isSameDay(_selectedDate, today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white.withOpacity(0.02),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: theme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            DateFormat('MMMM yyyy').format(_selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isToday ? theme.primary.withOpacity(0.2) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isToday ? theme.primary.withOpacity(0.4) : Colors.white10,
              ),
            ),
            child: Text(
              isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
              style: TextStyle(
                color: isToday ? theme.primary : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          if (!isToday)
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _selectedDate = today);
                _scrollToDate(today);
              },
              icon: const Icon(Icons.today_rounded, size: 16),
              label: const Text('Jump to Today'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.primary,
                side: BorderSide(color: theme.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRibbon(ColorScheme theme, List<TaskModel> tasks, List<GoalModel> goals) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.black.withOpacity(0.15),
      child: ListView.builder(
        controller: _ribbonController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, today);

          final hasTasks = tasks.any((t) => _isSameDay(t.scheduledDate, date));
          final hasGoals = goals.any((g) => _isSameDay(g.deadline, date));

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _scrollToDate(date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [theme.primary.withOpacity(0.3), theme.secondary.withOpacity(0.15)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isToday ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.02)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? theme.primary
                      : (isToday ? theme.primary.withOpacity(0.4) : Colors.white10),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? theme.primary : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isToday ? theme.primary : Colors.white),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasTasks)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasGoals)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: Colors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (!hasTasks && !hasGoals)
                        const SizedBox(height: 4),
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

  Widget _buildGoalCard(GoalModel goal, List<TaskModel> allTasks, ColorScheme theme) {
    final linkedTasks = allTasks.where((t) => t.goalId == goal.id).toList();
    final completedCount = linkedTasks.where((t) => t.isDone).length;
    final progress = linkedTasks.isEmpty ? 0.0 : (completedCount / linkedTasks.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag_rounded, color: Colors.amberAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (goal.category.isNotEmpty)
                      Text(
                        goal.category,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
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
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% completed',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                '$completedCount/${linkedTasks.length} tasks',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task, ColorScheme theme) {
    final isDone = task.isDone;

    return Container(
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFF0D2818).withOpacity(0.4) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? const Color(0xFF2ECC71).withOpacity(0.5) : Colors.white10,
          width: isDone ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Complete Checkbox
          Checkbox(
            value: isDone,
            activeColor: const Color(0xFF2ECC71),
            checkColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              widget.dbService.toggleTaskDone(task.id, val ?? false);
            },
          ),
          const SizedBox(width: 8),

          // Title & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: isDone ? const Color(0xFF2ECC71) : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDone ? const Color(0xFF2ECC71).withOpacity(0.7) : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.scheduledTime != null) ...[
                      Icon(Icons.access_time_rounded, size: 12, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        task.scheduledTime!,
                        style: TextStyle(fontSize: 11, color: isDone ? const Color(0xFF2ECC71) : Colors.white54),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (task.alarmEnabled) ...[
                      const Icon(Icons.alarm_on_rounded, size: 12, color: Colors.orangeAccent),
                      const SizedBox(width: 4),
                      const Text('Alarm', style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Move to Completed List button (Outbox button requested by user)
          IconButton(
            icon: const Icon(Icons.archive_outlined, size: 18),
            color: isDone ? const Color(0xFF2ECC71) : Colors.white54,
            tooltip: 'Move to Completed Items list',
            onPressed: () {
              widget.dbService.moveToCompleted(task.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Moved "${task.title}" to Completed Items'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
            tooltip: 'Edit Task',
            onPressed: () => _openTaskEditor(context, task),
          ),

          // Delete Button (Recycle Bin with 4-second undo)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            tooltip: 'Move to Trash',
            onPressed: () => _deleteTask(task),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_rounded, size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Nothing scheduled for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
            style: const TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openTaskCreator(context, _selectedDate),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Schedule Task for This Day'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _openTaskCreator(BuildContext context, DateTime date) {
    showDialog(
      context: context,
      builder: (_) => TaskCreationSheet(
        dbService: widget.dbService,
        initialDate: date,
      ),
    );
  }

  void _openTaskEditor(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (_) => TaskCreationSheet(
        dbService: widget.dbService,
        taskToEdit: task,
      ),
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

  void _deleteTask(TaskModel task) {
    widget.dbService.moveTaskToTrash(task.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Moved "${task.title}" to Trash'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => widget.dbService.restoreTask(task.id),
        ),
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
