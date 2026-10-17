import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import 'storage_service.dart';

class DatabaseService {
  final StorageService _storage;
  final String userId;

  static final Map<String, DatabaseService> _instances = {};

  factory DatabaseService({required String userId, StorageService? storage}) {
    return _instances.putIfAbsent(
      userId,
      () => DatabaseService._internal(userId, storage ?? StorageService()),
    );
  }

  final BehaviorSubject<List<TaskModel>> _tasksSubject = BehaviorSubject<List<TaskModel>>.seeded([]);
  final BehaviorSubject<List<GoalModel>> _goalsSubject = BehaviorSubject<List<GoalModel>>.seeded([]);

  DatabaseService._internal(this.userId, this._storage) {
    _initData();
  }

  Future<void> init() async {
    await _initData();
  }

  Future<void> _initData() async {
    final loadedTasks = await _storage.loadTasks();
    final loadedGoals = await _storage.loadGoals();

    if (loadedTasks.isEmpty && loadedGoals.isEmpty) {
      final seedTasks = [
        TaskModel(
          id: const Uuid().v4(),
          userId: userId,
          title: 'Welcome to Karaneeyaani',
          description: 'A flow-driven, premium offline task and goal roadmap application built for focus and speed.',
          order: 0,
          createdAt: DateTime.now(),
        ),
        TaskModel(
          id: const Uuid().v4(),
          userId: userId,
          title: 'Explore Timeline & Calendar',
          description: 'Check the calendar to view your scheduled roadmap and upcoming deadlines.',
          order: 1,
          createdAt: DateTime.now(),
        ),
      ];
      _tasksSubject.add(seedTasks);
      await _storage.saveTasks(seedTasks);
    } else {
      _tasksSubject.add(loadedTasks);
      _goalsSubject.add(loadedGoals);
    }
  }

  // --- STREAMS ---

  Stream<List<TaskModel>> get activeTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == userId) && t.status == TaskStatus.active && (t.goalId == null || t.goalId!.isEmpty))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get allActiveTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == userId) && t.status == TaskStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<GoalModel>> get activeGoals => _goalsSubject.stream.map((goals) {
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == userId) && g.status == GoalStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> tasksForGoal(String goalId) => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == userId) && t.goalId == goalId && t.status == TaskStatus.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get completedTasks => _tasksSubject.stream.map((tasks) {
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == userId) && t.status == TaskStatus.completed)
            .toList()
          ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime.now()).compareTo(a.updatedAt ?? a.createdAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get completedGoals => _goalsSubject.stream.map((goals) {
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == userId) && g.status == GoalStatus.completed)
            .toList()
          ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime.now()).compareTo(a.updatedAt ?? a.createdAt ?? DateTime.now()));
      });

  Stream<List<TaskModel>> get trashedTasks => _tasksSubject.stream.map((tasks) {
        final cutoff = DateTime.now().subtract(const Duration(days: 5));
        return tasks
            .where((t) => (t.userId.isEmpty || t.userId == userId) && t.status == TaskStatus.trashed && (t.deletedAt == null || t.deletedAt!.isAfter(cutoff)))
            .toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get trashedGoals => _goalsSubject.stream.map((goals) {
        final cutoff = DateTime.now().subtract(const Duration(days: 5));
        return goals
            .where((g) => (g.userId.isEmpty || g.userId == userId) && g.status == GoalStatus.trashed && (g.deletedAt == null || g.deletedAt!.isAfter(cutoff)))
            .toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  // --- TASK ACTIONS ---

  String addTask(TaskModel task) {
    task.userId = userId;
    if (task.id.isEmpty) {
      task.id = const Uuid().v4();
    }
    task.createdAt ??= DateTime.now();

    final current = List<TaskModel>.from(_tasksSubject.value);
    current.add(task);
    _tasksSubject.add(current);
    _storage.saveTasks(current);
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
    }
  }

  Future<void> updateTaskOrders(List<TaskModel> tasks) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    for (int i = 0; i < tasks.length; i++) {
      tasks[i].order = i;
      final idx = current.indexWhere((t) => t.id == tasks[i].id);
      if (idx != -1) {
        current[idx].order = i;
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  // --- GOAL ACTIONS ---

  String addGoal(GoalModel goal) {
    goal.userId = userId;
    if (goal.id.isEmpty) {
      goal.id = const Uuid().v4();
    }
    goal.createdAt ??= DateTime.now();

    final current = List<GoalModel>.from(_goalsSubject.value);
    current.add(goal);
    _goalsSubject.add(current);
    _storage.saveGoals(current);
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
    }
  }

  Future<void> updateGoalOrders(List<GoalModel> goals) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    for (int i = 0; i < goals.length; i++) {
      goals[i].order = i;
      final idx = current.indexWhere((g) => g.id == goals[i].id);
      if (idx != -1) {
        current[idx].order = i;
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

  // --- COMPLETION FLOWS ---

  Future<void> markGoalCompleted(String goalId) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      current[idx].status = GoalStatus.completed;
      current[idx].updatedAt = DateTime.now();
      _goalsSubject.add(current);
      await _storage.saveGoals(current);
    }
  }

  Future<void> markTaskCompleted(TaskModel task) async {
    await markTaskCompletedById(task.id);
    if (task.goalId != null && task.goalId!.isNotEmpty) {
      await _checkAndCompleteGoal(task.goalId!);
    }
  }

  Future<void> markTaskCompletedById(String taskId) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      current[idx].status = TaskStatus.completed;
      current[idx].isDone = true;
      current[idx].updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
      if (current[idx].goalId != null && current[idx].goalId!.isNotEmpty) {
        await _checkAndCompleteGoal(current[idx].goalId!);
      }
    }
  }

  Future<void> _checkAndCompleteGoal(String goalId) async {
    final currentTasks = _tasksSubject.value;
    final remainingActive = currentTasks.where((t) => t.goalId == goalId && t.status == TaskStatus.active);
    if (remainingActive.isEmpty) {
      await markGoalCompleted(goalId);
    }
  }

  // --- SOFT DELETE (TRASH) ---

  Future<void> softDeleteTask(TaskModel task) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      current[idx].status = TaskStatus.trashed;
      current[idx].deletedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
    }
  }

  Future<void> restoreTask(TaskModel task) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      current[idx].status = TaskStatus.active;
      current[idx].deletedAt = null;
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
      if (task.goalId != null && task.goalId!.isNotEmpty) {
        await restoreGoalById(task.goalId!);
      }
    }
  }

  Future<void> softDeleteGoal(GoalModel goal) async {
    final now = DateTime.now();
    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    final gIdx = currentGoals.indexWhere((g) => g.id == goal.id);
    if (gIdx != -1) {
      currentGoals[gIdx].status = GoalStatus.trashed;
      currentGoals[gIdx].deletedAt = now;
      _goalsSubject.add(currentGoals);
      await _storage.saveGoals(currentGoals);
    }

    // Soft delete associated tasks
    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    bool changed = false;
    for (var t in currentTasks) {
      if (t.goalId == goal.id && t.status == TaskStatus.active) {
        t.status = TaskStatus.trashed;
        t.deletedAt = now;
        changed = true;
      }
    }
    if (changed) {
      _tasksSubject.add(currentTasks);
      await _storage.saveTasks(currentTasks);
    }
  }

  Future<void> restoreGoal(GoalModel goal) async {
    await restoreGoalById(goal.id);
  }

  Future<void> restoreGoalById(String id) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == id);
    if (idx != -1) {
      current[idx].status = GoalStatus.active;
      current[idx].deletedAt = null;
      _goalsSubject.add(current);
      await _storage.saveGoals(current);
    }
  }

  // --- PERMANENT DELETIONS ---

  Future<void> deleteTaskPermanently(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    current.removeWhere((t) => t.id == id);
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> deleteGoalPermanently(String id) async {
    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    currentGoals.removeWhere((g) => g.id == id);
    _goalsSubject.add(currentGoals);
    await _storage.saveGoals(currentGoals);

    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    currentTasks.removeWhere((t) => t.goalId == id);
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);
  }

  // --- BATCH ACTIONS ---

  Future<void> restoreCompletedTaskById(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      current[idx].status = TaskStatus.active;
      current[idx].isDone = false;
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
    }
  }

  Future<void> restoreCompletedGoalById(String id) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idx = current.indexWhere((g) => g.id == id);
    if (idx != -1) {
      current[idx].status = GoalStatus.active;
      _goalsSubject.add(current);
      await _storage.saveGoals(current);
    }
  }

  Future<void> restoreCompletedTasks(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idsSet = taskIds.toSet();
    for (var t in current) {
      if (idsSet.contains(t.id)) {
        t.status = TaskStatus.active;
        t.isDone = false;
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> restoreCompletedGoals(Iterable<String> goalIds) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idsSet = goalIds.toSet();
    for (var g in current) {
      if (idsSet.contains(g.id)) {
        g.status = GoalStatus.active;
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

  Future<void> restoreTrashedTasks(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idsSet = taskIds.toSet();
    for (var t in current) {
      if (idsSet.contains(t.id)) {
        t.status = TaskStatus.active;
        t.deletedAt = null;
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> restoreTrashedGoals(Iterable<String> goalIds) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    final idsSet = goalIds.toSet();
    for (var g in current) {
      if (idsSet.contains(g.id)) {
        g.status = GoalStatus.active;
        g.deletedAt = null;
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

  Future<void> deleteTasksPermanently(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idsSet = taskIds.toSet();
    current.removeWhere((t) => idsSet.contains(t.id));
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> deleteGoalsPermanently(Iterable<String> goalIds) async {
    final idsSet = goalIds.toSet();
    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    currentGoals.removeWhere((g) => idsSet.contains(g.id));
    _goalsSubject.add(currentGoals);
    await _storage.saveGoals(currentGoals);

    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    currentTasks.removeWhere((t) => t.goalId != null && idsSet.contains(t.goalId));
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);
  }

  Future<void> clearAllTasks() async {
    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    currentTasks.removeWhere((t) => t.userId.isEmpty || t.userId == userId);
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);

    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    currentGoals.removeWhere((g) => g.userId.isEmpty || g.userId == userId);
    _goalsSubject.add(currentGoals);
    await _storage.saveGoals(currentGoals);
  }
}
