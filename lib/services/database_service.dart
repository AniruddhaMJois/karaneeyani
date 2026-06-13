import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  DatabaseService({required this.userId});

  // Get active tasks (not trashed, not completed)
  Stream<List<TaskModel>> get activeTasks {
    return _db.collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TaskStatus.active.name)
        .orderBy('order')
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  // Get active goals
  Stream<List<GoalModel>> get activeGoals {
    return _db.collection('goals')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: GoalStatus.active.name)
        .orderBy('order')
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
    });
  }

  // Get tasks for a specific goal
  Stream<List<TaskModel>> tasksForGoal(String goalId) {
    return _db.collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('goalId', isEqualTo: goalId)
        .where('status', isEqualTo: TaskStatus.active.name)
        .orderBy('order')
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  // Get completed tasks
  Stream<List<TaskModel>> get completedTasks {
    return _db.collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TaskStatus.completed.name)
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  // Get trashed tasks (Bin)
  Stream<List<TaskModel>> get trashedTasks {
    return _db.collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TaskStatus.trashed.name)
        .snapshots().map((snapshot) {
      // Filter out tasks older than 5 days client-side
      final cutoff = DateTime.now().subtract(const Duration(days: 5));
      final allTrashed = snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
      
      // Auto-delete old tasks permanently
      for (var task in allTrashed) {
        if (task.deletedAt != null && task.deletedAt!.isBefore(cutoff)) {
          deleteTaskPermanently(task.id);
        }
      }

      return allTrashed.where((task) => task.deletedAt == null || task.deletedAt!.isAfter(cutoff)).toList();
    });
  }

  // Get completed goals
  Stream<List<GoalModel>> get completedGoals {
    return _db.collection('goals')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: GoalStatus.completed.name)
        .snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
    });
  }

  // Get trashed goals (Bin)
  Stream<List<GoalModel>> get trashedGoals {
    return _db.collection('goals')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: GoalStatus.trashed.name)
        .snapshots().map((snapshot) {
      // Filter out goals older than 5 days client-side
      final cutoff = DateTime.now().subtract(const Duration(days: 5));
      final allTrashed = snapshot.docs.map((doc) => GoalModel.fromFirestore(doc)).toList();
      
      // Auto-delete old goals permanently
      for (var goal in allTrashed) {
        if (goal.deletedAt != null && goal.deletedAt!.isBefore(cutoff)) {
          deleteGoalPermanently(goal.id);
        }
      }

      return allTrashed.where((goal) => goal.deletedAt == null || goal.deletedAt!.isAfter(cutoff)).toList();
    });
  }

  // Create a new task instantly without hanging UI
  String addTask(TaskModel task) {
    task.userId = userId;
    final docRef = _db.collection('tasks').doc(); // Generates ID instantly on client
    docRef.set(task.toMap()).catchError((e) => print('Add task error: $e'));
    return docRef.id;
  }

  // Update a task instantly
  void updateTask(TaskModel task) {
    _db.collection('tasks').doc(task.id).update(task.toMap()).catchError((e) => print('Update task error: $e'));
  }

  // Batch update task orders
  Future<void> updateTaskOrders(List<TaskModel> tasks) async {
    final batch = _db.batch();
    for (int i = 0; i < tasks.length; i++) {
      tasks[i].order = i;
      final docRef = _db.collection('tasks').doc(tasks[i].id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit().catchError((e) => print('Batch update task orders error: $e'));
  }

  // Add a new goal
  String addGoal(GoalModel goal) {
    goal.userId = userId;
    final docRef = _db.collection('goals').doc();
    docRef.set(goal.toMap()).catchError((e) => print('Add goal error: $e'));
    return docRef.id;
  }

  // Update a goal
  void updateGoal(GoalModel goal) {
    _db.collection('goals').doc(goal.id).update(goal.toMap()).catchError((e) => print('Update goal error: $e'));
  }

  // Batch update goal orders
  Future<void> updateGoalOrders(List<GoalModel> goals) async {
    final batch = _db.batch();
    for (int i = 0; i < goals.length; i++) {
      goals[i].order = i;
      final docRef = _db.collection('goals').doc(goals[i].id);
      batch.update(docRef, {'order': i});
    }
    await batch.commit().catchError((e) => print('Batch update goal orders error: $e'));
  }

  // Complete a goal manually
  Future<void> markGoalCompleted(String goalId) async {
    await _db.collection('goals').doc(goalId).update({
      'status': GoalStatus.completed.name,
    });
  }

  // Complete a task
  Future<void> markTaskCompleted(TaskModel task) async {
    await markTaskCompletedById(task.id);
    if (task.goalId != null) {
      await _checkAndCompleteGoal(task.goalId!);
    }
  }

  // Complete a task by ID
  Future<void> markTaskCompletedById(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.completed.name,
    });
  }

  // Check if all tasks in a goal are completed and complete the goal
  Future<void> _checkAndCompleteGoal(String goalId) async {
    final activeTasksSnapshot = await _db.collection('tasks')
        .where('goalId', isEqualTo: goalId)
        .where('status', isEqualTo: TaskStatus.active.name)
        .get();

    if (activeTasksSnapshot.docs.isEmpty) {
      // No active tasks left for this goal, mark it completed
      await markGoalCompleted(goalId);
    }
  }

  // Soft delete a task (Move to bin)
  Future<void> softDeleteTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).update({
      'status': TaskStatus.trashed.name,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // Restore task from bin
  Future<void> restoreTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).update({
      'status': TaskStatus.active.name,
      'deletedAt': null,
    });
    if (task.goalId != null) {
      // Re-activate goal if restoring task
      await _db.collection('goals').doc(task.goalId).update({
        'status': GoalStatus.active.name,
      });
    }
  }

  // Permanent Delete
  Future<void> deleteTaskPermanently(String id) async {
    await _db.collection('tasks').doc(id).delete();
  }

  // Soft delete a goal (Move to bin)
  Future<void> softDeleteGoal(GoalModel goal) async {
    await _db.collection('goals').doc(goal.id).update({
      'status': GoalStatus.trashed.name,
      'deletedAt': FieldValue.serverTimestamp(),
    });
    // Soft delete all active tasks under this goal so they don't appear in the main task lists
    final tasksSnapshot = await _db.collection('tasks')
        .where('goalId', isEqualTo: goal.id)
        .where('status', isEqualTo: TaskStatus.active.name)
        .get();
    
    final batch = _db.batch();
    for (var doc in tasksSnapshot.docs) {
      batch.update(doc.reference, {
        'status': TaskStatus.trashed.name,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Restore goal from bin
  Future<void> restoreGoal(GoalModel goal) async {
    await _db.collection('goals').doc(goal.id).update({
      'status': GoalStatus.active.name,
      'deletedAt': null,
    });
  }

  // Permanent Delete Goal
  Future<void> deleteGoalPermanently(String id) async {
    await _db.collection('goals').doc(id).delete();
    // Delete all tasks associated with this goal
    final tasksSnapshot = await _db.collection('tasks').where('goalId', isEqualTo: id).get();
    final batch = _db.batch();
    for (var doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Clear all tasks (and goals for consistency)
  Future<void> clearAllTasks() async {
    final snapshot = await _db.collection('tasks').where('userId', isEqualTo: userId).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    final goalSnapshot = await _db.collection('goals').where('userId', isEqualTo: userId).get();
    for (var doc in goalSnapshot.docs) {
      await doc.reference.delete();
    }
  }
}
