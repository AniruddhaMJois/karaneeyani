import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { active, completed, trashed }

class TaskModel {
  String id;
  String userId;
  String title;
  String description;
  DateTime? endDate;
  bool hasAlarm;
  DateTime? alarmTime;
  TaskStatus status;
  DateTime? deletedAt;

  TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.endDate,
    this.hasAlarm = false,
    this.alarmTime,
    this.status = TaskStatus.active,
    this.deletedAt,
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
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      hasAlarm: data['hasAlarm'] ?? false,
      alarmTime: data['alarmTime'] != null ? (data['alarmTime'] as Timestamp).toDate() : null,
      status: parseStatus(data['status']),
      deletedAt: data['deletedAt'] != null ? (data['deletedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'hasAlarm': hasAlarm,
      'alarmTime': alarmTime != null ? Timestamp.fromDate(alarmTime!) : null,
      'status': status.name,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }
}
