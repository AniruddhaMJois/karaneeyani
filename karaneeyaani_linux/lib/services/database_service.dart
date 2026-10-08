import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import 'storage_service.dart';

class DatabaseService {
  final StorageService _storage;
  final String userId;

  final BehaviorSubject<List<TaskModel>> _tasksSubject = BehaviorSubject<List<TaskModel>>.seeded([]);
  final BehaviorSubject<List<GoalModel>> _goalsSubject = BehaviorSubject<List<GoalModel>>.seeded([]);

  DatabaseService({this.userId = 'local_user', StorageService? storage})
      : _storage = storage ?? StorageService() {
    _initData();
  }

  Future<void> init() async {
    await _initData();
  }

  Future<void> _initData() async {
    final loadedTasks = await _storage.loadTasks();
    final loadedGoals = await _storage.loadGoals();

    if (loadedTasks.isEmpty && loadedGoals.isEmpty) {
      // Seed initial helpful tasks
      final seedTasks = [
        TaskModel(
          id: const Uuid().v4(),
          userId: userId,
          title: 'Welcome to Karaneeyaani Linux',
          description: 'A native desktop task and goal roadmap application built for focus and speed.',
          order: 0,
          createdAt: DateTime.now(),
        ),
        TaskModel(
          id: const Uuid().v4(),
          userId: userId,
          title: 'Explore Timeline & Calendar',
          description: 'Click on Calendar in the sidebar to view your scheduled roadmap.',
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
            .where((t) => t.status == TaskStatus.active && (t.goalId == null || t.goalId!.isEmpty))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get allActiveTasks => _tasksSubject.stream.map((tasks) {
        return tasks.where((t) => t.status == TaskStatus.active).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<GoalModel>> get activeGoals => _goalsSubject.stream.map((goals) {
        return goals.where((g) => g.status == GoalStatus.active).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> tasksForGoal(String goalId) => _tasksSubject.stream.map((tasks) {
        return tasks.where((t) => t.goalId == goalId && t.status == TaskStatus.active).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      });

  Stream<List<TaskModel>> get completedTasks => _tasksSubject.stream.map((tasks) {
        return tasks.where((t) => t.status == TaskStatus.completed).toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime.now()).compareTo(a.updatedAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get completedGoals => _goalsSubject.stream.map((goals) {
        return goals.where((g) => g.status == GoalStatus.completed).toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime.now()).compareTo(a.updatedAt ?? DateTime.now()));
      });

  Stream<List<TaskModel>> get trashedTasks => _tasksSubject.stream.map((tasks) {
        return tasks.where((t) => t.status == TaskStatus.trashed).toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  Stream<List<GoalModel>> get trashedGoals => _goalsSubject.stream.map((goals) {
        return goals.where((g) => g.status == GoalStatus.trashed).toList()
          ..sort((a, b) => (b.deletedAt ?? DateTime.now()).compareTo(a.deletedAt ?? DateTime.now()));
      });

  // --- TASK ACTIONS ---

  String addTask(TaskModel task) {
    task.userId = userId;
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
        current[idx] = tasks[i];
      }
    }
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> markTaskCompleted(TaskModel task) async {
    task.status = TaskStatus.completed;
    task.isDone = true;
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
      current[idx].updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
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
        }
      }
    }
  }

  Future<void> restoreCompletedTaskById(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      current[idx].status = TaskStatus.active;
      current[idx].isDone = false;
      current[idx].updatedAt = DateTime.now();
      _tasksSubject.add(current);
      await _storage.saveTasks(current);
    }
  }

  Future<void> deleteTaskPermanently(String id) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    current.removeWhere((t) => t.id == id);
    _tasksSubject.add(current);
    await _storage.saveTasks(current);
  }

  Future<void> restoreCompletedTasks(Iterable<String> taskIds) async {
    final current = List<TaskModel>.from(_tasksSubject.value);
    for (final id in taskIds) {
      final idx = current.indexWhere((t) => t.id == id);
      if (idx != -1) {
        current[idx].status = TaskStatus.active;
        current[idx].isDone = false;
        current[idx].updatedAt = DateTime.now();
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
  }

  // --- GOAL ACTIONS ---

  String addGoal(GoalModel goal) {
    goal.userId = userId;
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
        current[idx] = goals[i];
      }
    }
    _goalsSubject.add(current);
    await _storage.saveGoals(current);
  }

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
    }
  }

  Future<void> deleteGoalPermanently(String id) async {
    final currentGoals = List<GoalModel>.from(_goalsSubject.value);
    currentGoals.removeWhere((g) => g.id == id);
    _goalsSubject.add(currentGoals);
    await _storage.saveGoals(currentGoals);

    // Also delete all tasks belonging to this goal
    final currentTasks = List<TaskModel>.from(_tasksSubject.value);
    currentTasks.removeWhere((t) => t.goalId == id);
    _tasksSubject.add(currentTasks);
    await _storage.saveTasks(currentTasks);
  }

  Future<void> restoreCompletedGoals(Iterable<String> goalIds) async {
    final current = List<GoalModel>.from(_goalsSubject.value);
    for (final id in goalIds) {
      final idx = current.indexWhere((g) => g.id == id);
      if (idx != -1) {
        current[idx].status = GoalStatus.active;
        current[idx].updatedAt = DateTime.now();
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
