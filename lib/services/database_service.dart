import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  DatabaseService({required this.userId});

  // Get active tasks (not trashed, not completed)
  Stream<List<TaskModel>> get activeTasks {
    return _db.collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TaskStatus.active.name)
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

  // Complete a task
  Future<void> markTaskCompleted(TaskModel task) async {
    await markTaskCompletedById(task.id);
  }

  // Complete a task by ID
  Future<void> markTaskCompletedById(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': TaskStatus.completed.name,
    });
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
  }

  // Permanent Delete
  Future<void> deleteTaskPermanently(String id) async {
    await _db.collection('tasks').doc(id).delete();
  }

  // Clear all tasks
  Future<void> clearAllTasks() async {
    final snapshot = await _db.collection('tasks').where('userId', isEqualTo: userId).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
