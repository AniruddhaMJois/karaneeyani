import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get a stream of tasks
  Stream<List<TaskModel>> get tasks {
    return _db.collection('tasks').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();
    });
  }

  // Create a new task
  Future<void> addTask(TaskModel task) async {
    await _db.collection('tasks').add(task.toMap());
  }

  // Update a task
  Future<void> updateTask(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).update(task.toMap());
  }

  // Delete a task
  Future<void> deleteTask(String id) async {
    await _db.collection('tasks').doc(id).delete();
  }

  // Toggle completion status
  Future<void> toggleTaskCompletion(TaskModel task) async {
    await _db.collection('tasks').doc(task.id).update({'isCompleted': !task.isCompleted});
  }
}
