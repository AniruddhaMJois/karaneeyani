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
  String progressStatus;
  DateTime? completedAt;
  String? extensionSeriesId;
  int? extendedDaysCount;

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
    this.progressStatus = '',
    this.completedAt,
    this.extensionSeriesId,
    this.extendedDaysCount,
  })  : endDate = scheduledDate ?? endDate,
        hasAlarm = alarmEnabled ?? hasAlarm;

  TaskModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? endDate,
    bool? hasAlarm,
    DateTime? alarmTime,
    String? goalId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? order,
    DateTime? deletedAt,
    bool? isDone,
    List<int>? repeatDays,
    String? progressStatus,
    DateTime? completedAt,
    String? extensionSeriesId,
    int? extendedDaysCount,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      alarmTime: alarmTime ?? this.alarmTime,
      goalId: goalId ?? this.goalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      order: order ?? this.order,
      deletedAt: deletedAt ?? this.deletedAt,
      isDone: isDone ?? this.isDone,
      repeatDays: repeatDays ?? List.from(this.repeatDays),
      progressStatus: progressStatus ?? this.progressStatus,
      completedAt: completedAt ?? this.completedAt,
      extensionSeriesId: extensionSeriesId ?? this.extensionSeriesId,
      extendedDaysCount: extendedDaysCount ?? this.extendedDaysCount,
    );
  }

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
      'progressStatus': progressStatus,
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      if (extensionSeriesId != null) 'extensionSeriesId': extensionSeriesId,
      if (extendedDaysCount != null) 'extendedDaysCount': extendedDaysCount,
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
      userId: map['userId'] ?? map['user_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['scheduledDate'] ?? map['end_date']),
      hasAlarm: map['hasAlarm'] ?? map['alarmEnabled'] ?? map['has_alarm'] ?? false,
      alarmTime: parseDate(map['alarmTime'] ?? map['alarm_time']),
      goalId: map['goalId'] ?? map['goal_id'],
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
      order: map['order'] ?? map['order_index'] ?? 0,
      deletedAt: parseDate(map['deletedAt'] ?? map['deleted_at']),
      isDone: map['isDone'] ?? map['is_completed'] ?? false,
      repeatDays: map['repeatDays'] != null
          ? List<int>.from(map['repeatDays'])
          : (map['repeat_days'] != null ? List<int>.from(map['repeat_days']) : const []),
      progressStatus: map['progressStatus'] ?? map['progress_status'] ?? '',
      completedAt: parseDate(map['completedAt'] ?? map['completed_at']),
      extensionSeriesId: map['extensionSeriesId'] ?? map['extension_series_id'],
      extendedDaysCount: map['extendedDaysCount'] ?? map['extended_days_count'],
    );
  }
}
