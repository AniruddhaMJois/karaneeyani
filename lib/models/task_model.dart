import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { active, completed, trashed }

class TaskModel {
  String id;
  String userId;
  String title;
  String description;
  TaskStatus status;
  DateTime? endDate;
  bool hasAlarm;
  DateTime? alarmTime;
  String? goalId;
  DateTime? createdAt;
  int order;
  DateTime? deletedAt;
  bool isDone;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.status = TaskStatus.active,
    this.endDate,
    this.hasAlarm = false,
    this.alarmTime,
    this.goalId,
    this.createdAt,
    this.order = 0,
    this.deletedAt,
    this.isDone = false,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    
    TaskStatus parseStatus(String? statusStr) {
      if (statusStr == 'completed') return TaskStatus.completed;
      if (statusStr == 'trashed') return TaskStatus.trashed;
      return TaskStatus.active;
    }

    return TaskModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: parseStatus(data['status']),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      hasAlarm: data['hasAlarm'] ?? false,
      alarmTime: data['alarmTime'] != null ? (data['alarmTime'] as Timestamp).toDate() : null,
      goalId: data['goalId'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      order: data['order'] ?? 0,
      deletedAt: data['deletedAt'] != null ? (data['deletedAt'] as Timestamp).toDate() : null,
      isDone: data['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'hasAlarm': hasAlarm,
      'alarmTime': alarmTime != null ? Timestamp.fromDate(alarmTime!) : null,
      'goalId': goalId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'order': order,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      'isDone': isDone,
    };
  }
}
