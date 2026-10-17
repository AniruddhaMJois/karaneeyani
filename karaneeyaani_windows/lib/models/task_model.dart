import 'package:intl/intl.dart';

enum TaskStatus { active, completed, trashed }

class TaskModel {
  String id;
  String userId;
  String title;
  String description;
  bool isDone;
  TaskStatus status;
  DateTime? endDate;
  DateTime? alarmTime;
  bool hasAlarm;
  int order;
  String? goalId;
  DateTime? deletedAt;
  DateTime? createdAt;
  DateTime? updatedAt;

  DateTime? get scheduledDate => endDate;
  set scheduledDate(DateTime? val) => endDate = val;

  bool get alarmEnabled => hasAlarm;
  set alarmEnabled(bool val) => hasAlarm = val;

  String? get scheduledTime => alarmTime != null ? DateFormat('h:mm a').format(alarmTime!) : null;

  TaskModel({
    required this.id,
    this.userId = '',
    required this.title,
    this.description = '',
    this.isDone = false,
    this.status = TaskStatus.active,
    DateTime? endDate,
    DateTime? scheduledDate,
    this.alarmTime,
    bool hasAlarm = false,
    bool? alarmEnabled,
    this.order = 0,
    this.goalId,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  })  : endDate = scheduledDate ?? endDate,
        hasAlarm = alarmEnabled ?? hasAlarm;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'isDone': isDone,
      'status': status.name,
      'endDate': endDate?.toIso8601String(),
      'alarmTime': alarmTime?.toIso8601String(),
      'hasAlarm': hasAlarm,
      'order': order,
      'goalId': goalId,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    TaskStatus parseStatus(dynamic s) {
      if (s == 'completed') return TaskStatus.completed;
      if (s == 'trashed') return TaskStatus.trashed;
      return TaskStatus.active;
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return TaskModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      isDone: map['isDone'] ?? false,
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['scheduledDate']),
      alarmTime: parseDate(map['alarmTime']),
      hasAlarm: map['hasAlarm'] ?? map['alarmEnabled'] ?? false,
      order: map['order'] ?? 0,
      goalId: map['goalId'],
      deletedAt: parseDate(map['deletedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
