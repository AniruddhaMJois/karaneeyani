import 'package:intl/intl.dart';

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
  DateTime? updatedAt;
  int order;
  DateTime? deletedAt;
  bool isDone;
  List<int> repeatDays;

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
    this.status = TaskStatus.active,
    DateTime? endDate,
    DateTime? scheduledDate,
    bool hasAlarm = false,
    bool? alarmEnabled,
    this.alarmTime,
    this.goalId,
    this.createdAt,
    this.updatedAt,
    this.order = 0,
    this.deletedAt,
    this.isDone = false,
    this.repeatDays = const [],
  })  : endDate = scheduledDate ?? endDate,
        hasAlarm = alarmEnabled ?? hasAlarm;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'endDate': endDate?.toIso8601String(),
      'hasAlarm': hasAlarm,
      'alarmTime': alarmTime?.toIso8601String(),
      'goalId': goalId,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'order': order,
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      'isDone': isDone,
      'repeatDays': repeatDays,
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
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['scheduledDate']),
      hasAlarm: map['hasAlarm'] ?? map['alarmEnabled'] ?? false,
      alarmTime: parseDate(map['alarmTime']),
      goalId: map['goalId'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      order: map['order'] ?? 0,
      deletedAt: parseDate(map['deletedAt']),
      isDone: map['isDone'] ?? false,
      repeatDays: map['repeatDays'] != null ? List<int>.from(map['repeatDays']) : const [],
    );
  }
}
