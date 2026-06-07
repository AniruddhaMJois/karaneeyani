import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  String id;
  String title;
  String description;
  DateTime? endDate;
  bool hasAlarm;
  DateTime? alarmTime;
  bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.endDate,
    this.hasAlarm = false,
    this.alarmTime,
    this.isCompleted = false,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      hasAlarm: data['hasAlarm'] ?? false,
      alarmTime: data['alarmTime'] != null ? (data['alarmTime'] as Timestamp).toDate() : null,
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'hasAlarm': hasAlarm,
      'alarmTime': alarmTime != null ? Timestamp.fromDate(alarmTime!) : null,
      'isCompleted': isCompleted,
    };
  }
}
