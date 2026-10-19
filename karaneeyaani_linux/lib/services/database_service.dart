import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import 'storage_service.dart';
import 'supabase_sync_service.dart';

class DatabaseService {
  final StorageService _storage;
  final SupabaseSyncService _syncService;
  String _userId;

  String get userId => _userId;

  final BehaviorSubject<List<TaskModel>> _tasksSubject = BehaviorSubject<List<TaskModel>>.seeded([]);
  final BehaviorSubject<List<GoalModel>> _goalsSubject = BehaviorSubject<List<GoalModel>>.seeded([]);

  DatabaseService({
    String userId = 'local_user',
    StorageService? storage,
    SupabaseSyncService? syncService,
  })  : _userId = userId,
        _storage = storage ?? StorageService(),
        _syncService = syncService ?? SupabaseSyncService(storage: storage ?? StorageService()) {
    _initData();
  }

  Future<void> init() async {
    await _initData();
  }

  Future<void> reloadForUser(String newUserId) async {
    _userId = newUserId;
    await _initData();
  }

  Future<void> _initData() async {
    final loadedTasks = await _storage.loadTasks(
      onCompletedPurged: (purgedIds) {
        for (final id in purgedIds) {
          _syncService.enqueueTaskDelete(id);
        }
      },
    );
    final loadedGoals = await _storage.loadGoals();

    if (loadedTasks.isEmpty && loadedGoals.isEmpty) {
      // Seed initial helpful tasks
      final seedTasks = [
        TaskModel(
          id: const Uuid().v4(),
          userId: _userId,
          title: 'Welcome to Karaneeyaani Linux',
          description: 'A native desktop task and goal roadmap application built for focus and speed.',
          order: 0,
          createdAt: DateTime.now(),
        ),
        TaskModel(
          id: const Uuid().v4(),
          userId: _userId,
          title: 'Explore Timeline & Calendar',
          description: 'Click on Calendar in the sidebar to view your scheduled roadmap.',
          order: 1,
          createdAt: DateTime.now(),
        ),
      ];
      _tasksSubject.add(seedTasks);
      await _storage.saveTasks(seedTasks);
      for (var t in seedTasks) {
        _syncService.enqueueTaskUpsert(t);
      }
    } else {
      _tasksSubject.add(loadedTasks);
      _goalsSubject.add(loadedGoals);
      await checkAndPurgeOldCompletedTasks();
    }

    // Trigger cloud synchronization if active user session is present
    if (_userId.isNotEmpty && _userId != 'local_user') {
      unawaited(_syncService.syncAll(_userId).then((_) async {
        final refreshedTasks = await _storage.loadTasks();
        final refreshedGoals = await _storage.loadGoals();
        _tasksSubject.add(refreshedTasks);
        _goalsSubject.add(refreshedGoals);
      }));
    }
  }

  /// 20-Day Completed Tasks Auto-Purge:
  /// Automatically and permanently purges any task from local storage and Supabase
  /// once it reaches 20 continuous days in the completed state (now - completedAt >= 20 days).
  Future<void> checkAndPurgeOldCompletedTasks() async {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 20));
    final current = List<TaskModel>.from(_tasksSubject.value);
    final List<String> toPurge = [];
    final kept = <TaskModel>[];

    for (final task in current) {
      if (task.status == TaskStatus.completed) {
        final compDate = task.completedAt ?? task.updatedAt ?? task.createdAt ?? now;
        if (now.difference(compDate).inDays >= 20 || compDate.isBefore(cutoff)) {
          toPurge.add(task.id);
          continue;
        }
      }
      kept.add(task);
    }

    if (toPurge.isNotEmpty) {
      _tasksSubject.add(kept);
      await _storage.saveTasks(kept);
      for (final id in toPurge) {
        await _syncService.enqueueTaskDelete(id);
      }
    }
  }

  // --- STREAMS ---

  Stream<List<TaskModel>> get activeTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == _userId || _userId == 'local_user') &&
                          t.status == TaskStatus.active &&
                          (t.goalId == null || t.goalId!.isEmpty))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get allActiveTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == _userId || _userId == 'local_user') &&
                          t.status == TaskStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<GoalModel>> get activeGoals => _goalsSubject.stream.map((goals) {
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == _userId || _userId == 'local_user') &&
                          g.status == GoalStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> tasksForGoal(String goalId) => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == _userId || _userId == 'local_user') &&
                          t.goalId == goalId &&
                          t.status == TaskStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get completedTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == _userId || _userId == 'local_user') &&
                          t.status == TaskStatus.completed)
            .toList()
          ..sort((a, b) => (b.completedAt ?? b.updatedAt ?? DateTime.now())
              .compareTo(a.completedAt ?? a.updatedAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get completedGoals => _goalsSubject.stream.map((goals) {
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == _userId || _userId == 'local_user') &&
                          g.status == GoalStatus.completed)
            .toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime.now()).compareTo(a.updatedAt ?? DateTime.now()));
      });

  Stream<List<TaskModel>> get trashedTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == _userId || _userId == 'local_user') &&
                          t.status == TaskStatus.trashed)
            .toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get trashedGoals => _goalsSubject.stream.map((goals) {
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == _userId || _userId == 'local_user') &&
                          g.status == GoalStatus.trashed)
            .toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  // --- TASK ACTIONS ---

  String addTask(TaskModel task) {
    if (task.userId.isEmpty) {
      task.userId = userId;
    }
    if (task.id.isEmpty) {
      task.id = const Uuid().v4();
    }
    task.createdAt = DateTime.now();
    task.updatedAt = DateTime.now();

    final current = List<TaskModel>.from(_tasksSubject.value);
    task.order = current.length;
    current.add(task);
    _tasksSubject.add(current);
    _storage.saveTasks(current);
    _syncService.enqueueTaskUpsert(task);
    return task.id;
  }

  void updateTask(TaskModel task) {
    task.updatedAt = DateTime.now();
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      current[idx] = task;
      _tasksSubject.add(current);
      _storage.saveTasks(current);
      _syncService.enqueueTaskUpsert(task);
    }
  }

  void updateTaskProgressNotes(String id, String notes) {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      current[idx].progressNotes = notes;
      current[idx].updatedAt = DateTime.now();
      _tasksSubject.add(current);
      _storage.saveTasks(current);
      _syncService.enqueueTaskUpsert(current[idx]);
    }
  }

  Future<void> updateTaskOrders(List<TaskModel> tasks) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    for (int i = 0; i < tasks.length; i++) {
      tasks[i].order = i;
      final idx = current.indexWhere((t) => t.id == tasks[i].id);
      if (idx != -1) {
        current[idx] = tasks[i];
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
    for (var t in tasks) {
      _syncService.enqueueTaskUpsert(t);
    }
  }

  Future<void> markTaskCompleted(TaskModel task) async {
    task.status = TaskStatus.completed;
    task.isDone = true;
    task.completedAt = DateTime.now();
    task.updatedAt = DateTime.now();
    updateTask(task);

    if (task.goalId != null && task.goalId!.isNotEmpty) {
      await _checkAndCompleteGoal(task.goalId!);
    }
  }

  Future<void> markTaskCompletedById(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final task = current[idx];
      task.status = TaskStatus.completed;
      task.isDone = true;
      task.completedAt = DateTime.now();
      task.updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
      _syncService.enqueueTaskUpsert(task);
      if (task.goalId != null && task.goalId!.isNotEmpty) {
        await _checkAndCompleteGoal(task.goalId!);
      }
    }
  }

  Future<void> _checkAndCompleteGoal(String goalId) async {
    final activeCount = _tasksSubject.value.where((t) => t.goalId == goalId && t.status == TaskStatus.active).length;
    if (activeCount == 0) {
      await markGoalCompleted(goalId);
    }
  }

  Future<void> softDeleteTask(TaskModel task) async {
    task.status = TaskStatus.trashed;
    task.deletedAt = DateTime.now();
    task.updatedAt = DateTime.now();
    updateTask(task);
  }

  Future<void> toggleTaskDone(String id, bool isDone) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      current[idx].isDone = isDone;
      if (isDone) {
        current[idx].completedAt = DateTime.now();
      } else {
        current[idx].completedAt = null;
      }
      current[idx].updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
      _syncService.enqueueTaskUpsert(current[idx]);
    }
  }

  Future<void> moveToCompleted(String id) => markTaskCompletedById(id);

  Future<void> moveTaskToTrash(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      await softDeleteTask(current[idx]);
    }
  }

  Future<void> restoreTask(dynamic taskOrId) async {
    if (taskOrId is String) {
      await restoreTrashedTasks([taskOrId]);
    } else if (taskOrId is TaskModel) {
      taskOrId.status = TaskStatus.active;
      taskOrId.deletedAt = null;
      taskOrId.updatedAt = DateTime.now();
      updateTask(taskOrId);

      if (taskOrId.goalId != null && taskOrId.goalId!.isNotEmpty) {
        final currentGoals = List<GoalModel>.from(_goalsSubject.value);
        final gIdx = currentGoals.indexWhere((g) => g.id == taskOrId.goalId);
        if (gIdx != -1) {
          currentGoals[gIdx].status = GoalStatus.active;
          _goalsSubject.add(currentGoals);
          await _storage.saveGoals(currentGoals);
          _syncService.enqueueGoalUpsert(currentGoals[gIdx]);
        }
      }
    }
  }

  /// Restore completed task only if within 20 days window
  Future<bool> restoreCompletedTaskById(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final task = current[idx];
      final compDate = task.completedAt ?? task.updatedAt ?? task.createdAt ?? DateTime.now();
      if (DateTime.now().difference(compDate).inDays >= 20) {
        return false; // Retention expired
      }
      task.status = TaskStatus.active;
      task.isDone = false;
      task.completedAt = null;
      task.updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
      _syncService.enqueueTaskUpsert(task);
      return true;
    }
    return false;
  }

  Future<void> deleteTaskPermanently(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    current.removeWhere((t) => t.id == id);
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
    _syncService.enqueueTaskDelete(id);
  }

  Future<void> restoreCompletedTasks(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final now = DateTime.now();
    for (final id in taskIds) {
      final idx = current.indexWhere((t) => t.id == id);
      if (idx != -1) {
        final task = current[idx];
        final compDate = task.completedAt ?? task.updatedAt ?? task.createdAt ?? now;
        if (now.difference(compDate).inDays < 20) {
          task.status = TaskStatus.active;
          task.isDone = false;
          task.completedAt = null;
          task.updatedAt = DateTime.now();
          _syncService.enqueueTaskUpsert(task);
        }
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> restoreTrashedTasks(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    for (final id in taskIds) {
      final idx = current.indexWhere((t) => t.id == id);
      if (idx != -1) {
        current[idx].status = TaskStatus.active;
        current[idx].deletedAt = null;
        current[idx].updatedAt = DateTime.now();
        _syncService.enqueueTaskUpsert(current[idx]);
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> deleteTasksPermanently(Iterable<String> taskIds) async {
    final idsSet = taskIds.toSet();
    final current = List<TaskModel>.from(_tasksSubject.value);
    current.removeWhere((t) => idsSet.contains(t.id));
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
    for (final id in idsSet) {
      _syncService.enqueueTaskDelete(id);
    }
  }

  // --- TASK EXTENSION ENGINE ("Extend this to") ---

  /// Extend task for N preset days (1, 5, 10 days)
  Future<List<TaskModel>> extendTask(TaskModel baseTask, int days) async {
    if (days <= 0) return [];
    final now = DateTime.now();
    final startDate = baseTask.endDate ?? DateTime(now.year, now.month, now.day);
    final seriesId = baseTask.seriesId ?? const Uuid().v4();
    final totalDays = (baseTask.extendedDays ?? 1) + days;

    baseTask.seriesId = seriesId;
    baseTask.extendedDays = totalDays;
    baseTask.endDate = startDate;
    updateTask(baseTask);

    final created = <TaskModel>[];
    for (int i = 1; i <= days; i++) {
      final targetDate = startDate.add(Duration(days: i));
      final newTask = TaskModel(
        id: const Uuid().v4(),
        userId: baseTask.userId.isNotEmpty ? baseTask.userId : userId,
        title: baseTask.title,
        description: baseTask.description,
        progressNotes: baseTask.progressNotes, // Title and progress notes copied
        isDone: false, // Independent per day!
        status: TaskStatus.active,
        endDate: targetDate,
        hasAlarm: baseTask.hasAlarm,
        alarmTime: baseTask.alarmTime != null
            ? DateTime(targetDate.year, targetDate.month, targetDate.day, baseTask.alarmTime!.hour, baseTask.alarmTime!.minute)
            : null,
        goalId: baseTask.goalId,
        seriesId: seriesId,
        extendedDays: totalDays,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      addTask(newTask);
      created.add(newTask);
    }
    return created;
  }

  /// Extend task for a custom date range
  Future<List<TaskModel>> extendTaskToDateRange(TaskModel baseTask, DateTime start, DateTime end) async {
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day);
    if (cleanEnd.isBefore(cleanStart)) return [];

    final totalDays = cleanEnd.difference(cleanStart).inDays + 1;
    final seriesId = baseTask.seriesId ?? const Uuid().v4();

    baseTask.seriesId = seriesId;
    baseTask.extendedDays = totalDays;
    baseTask.endDate = cleanStart;
    updateTask(baseTask);

    final created = <TaskModel>[];
    for (int i = 1; i < totalDays; i++) {
      final targetDate = cleanStart.add(Duration(days: i));
      final newTask = TaskModel(
        id: const Uuid().v4(),
        userId: baseTask.userId.isNotEmpty ? baseTask.userId : userId,
        title: baseTask.title,
        description: baseTask.description,
        progressNotes: baseTask.progressNotes,
        isDone: false, // Independent per day!
        status: TaskStatus.active,
        endDate: targetDate,
        hasAlarm: baseTask.hasAlarm,
        alarmTime: baseTask.alarmTime != null
            ? DateTime(targetDate.year, targetDate.month, targetDate.day, baseTask.alarmTime!.hour, baseTask.alarmTime!.minute)
            : null,
        goalId: baseTask.goalId,
        seriesId: seriesId,
        extendedDays: totalDays,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      addTask(newTask);
      created.add(newTask);
    }
    return created;
  }

  // --- GOAL ACTIONS ---

  String addGoal(GoalModel goal) {
    if (goal.userId.isEmpty) {
      goal.userId = userId;
    }
    if (goal.id.isEmpty) {
      goal.id = const Uuid().v4();
    }
    goal.createdAt = DateTime.now();
    goal.updatedAt = DateTime.now();

    final current = List<GoalModel>.from(_goalsSubject.value);
    goal.order = current.length;
    current.add(goal);
    _goalsSubject.add(current);
    _storage.saveGoals(current);
    _syncService.enqueueGoalUpsert(goal);
    return goal.id;
  }

  void updateGoal(GoalModel goal) {
    goal.updatedAt = DateTime.now();
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      current[idx] = goal;
      _goalsSubject.add(current);
      _storage.saveGoals(current);
      _syncService.enqueueGoalUpsert(goal);
    }
  }

  Future<void> updateGoalOrders(List<GoalModel> goals) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    for (int i = 0; i < goals.length; i++) {
      goals[i].order = i;
      final idx = current.indexWhere((g) => g.id == goals[i].id);
      if (idx != -1) {
        current[idx] = goals[i];
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
    for (var g in goals) {
      _syncService.enqueueGoalUpsert(g);
    }
  }

  Future<void> markGoalCompleted(String goalId) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      current[idx].status = GoalStatus.completed;
      current[idx].updatedAt = DateTime.now();
      _goalsSubject.add(current);
      await _storage.saveGoals(current);
      _syncService.enqueueGoalUpsert(current[idx]);
    }
  }

  Future<void> softDeleteGoal(GoalModel goal) async {
    goal.status = GoalStatus.trashed;
    goal.deletedAt = DateTime.now();
    goal.updatedAt = DateTime.now();
    updateGoal(goal);

    // Soft delete all active tasks under this goal
    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    for (var task in currentTasks) {
      if (task.goalId == goal.id && task.status == TaskStatus.active) {
        task.status = TaskStatus.trashed;
        task.deletedAt = DateTime.now();
        _syncService.enqueueTaskUpsert(task);
      }
    }
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);
  }

  Future<void> moveGoalToCompleted(String id) => markGoalCompleted(id);

  Future<void> moveGoalToTrash(String id) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == id);
    if (idx != -1) {
      await softDeleteGoal(current[idx]);
    }
  }

  Future<void> restoreGoal(dynamic goalOrId) async {
    if (goalOrId is String) {
      await restoreTrashedGoals([goalOrId]);
    } else if (goalOrId is GoalModel) {
      goalOrId.status = GoalStatus.active;
      goalOrId.deletedAt = null;
      goalOrId.updatedAt = DateTime.now();
      updateGoal(goalOrId);
    }
  }

  Future<void> restoreCompletedGoalById(String id) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == id);
    if (idx != -1) {
      current[idx].status = GoalStatus.active;
      current[idx].updatedAt = DateTime.now();
      _goalsSubject.add(current);
      await _storage.saveGoals(current);
      _syncService.enqueueGoalUpsert(current[idx]);
    }
  }

  Future<void> deleteGoalPermanently(String id) async {
    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    currentGoals.removeWhere((g) => g.id == id);
    _goalsSubject.add(currentGoals);
    await _storage.saveGoals(currentGoals);
    _syncService.enqueueGoalDelete(id);

    // Also delete all tasks belonging to this goal
    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    final toDeleteTasks = currentTasks.where((t) => t.goalId == id).toList();
    currentTasks.removeWhere((t) => t.goalId == id);
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);
    for (var t in toDeleteTasks) {
      _syncService.enqueueTaskDelete(t.id);
    }
  }

  Future<void> restoreCompletedGoals(Iterable<String> goalIds) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    for (final id in goalIds) {
      final idx = current.indexWhere((g) => g.id == id);
      if (idx != -1) {
        current[idx].status = GoalStatus.active;
        current[idx].updatedAt = DateTime.now();
        _syncService.enqueueGoalUpsert(current[idx]);
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

  Future<void> restoreTrashedGoals(Iterable<String> goalIds) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    for (final id in goalIds) {
      final idx = current.indexWhere((g) => g.id == id);
      if (idx != -1) {
        current[idx].status = GoalStatus.active;
        current[idx].deletedAt = null;
        current[idx].updatedAt = DateTime.now();
        _syncService.enqueueGoalUpsert(current[idx]);
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

  Future<void> deleteGoalsPermanently(Iterable<String> goalIds) async {
    for (final id in goalIds) {
      await deleteGoalPermanently(id);
    }
  }

  Future<void> clearAllTasks() async {
    _tasksSubject.add([]);
    _goalsSubject.add([]);
    await _storage.clearAll();
  }

  void dispose() {
    _tasksSubject.close();
    _goalsSubject.close();
  }
}
