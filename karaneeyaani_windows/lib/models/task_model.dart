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

  // New fields for Windows Desktop Edition
  String progressNotes;
  DateTime? completedAt;
  String? seriesId;
  int? extendedDays;
  List<int> repeatDays;

  // Getters & Setters for aliases
  DateTime? get scheduledDate => endDate;
  set scheduledDate(DateTime? val) => endDate = val;

  bool get alarmEnabled => hasAlarm;
  set alarmEnabled(bool val) => hasAlarm = val;

  String? get scheduledTime => alarmTime != null ? DateFormat('h:mm a').format(alarmTime!) : null;

  String get progressStatus => progressNotes;
  set progressStatus(String val) => progressNotes = val;

  String? get extensionSeriesId => seriesId;
  set extensionSeriesId(String? val) => seriesId = val;

  int? get extendedDaysCount => extendedDays;
  set extendedDaysCount(int? val) => extendedDays = val;

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
    String progressNotes = '',
    String? progressStatus,
    this.completedAt,
    String? seriesId,
    String? extensionSeriesId,
    int? extendedDays,
    int? extendedDaysCount,
    this.repeatDays = const [],
  })  : endDate = scheduledDate ?? endDate,
        hasAlarm = alarmEnabled ?? hasAlarm,
        progressNotes = progressStatus ?? progressNotes,
        seriesId = extensionSeriesId ?? seriesId,
        extendedDays = extendedDaysCount ?? extendedDays;

  TaskModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    bool? isDone,
    TaskStatus? status,
    DateTime? endDate,
    DateTime? alarmTime,
    bool? hasAlarm,
    int? order,
    String? goalId,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? progressNotes,
    DateTime? completedAt,
    String? seriesId,
    int? extendedDays,
    List<int>? repeatDays,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
      alarmTime: alarmTime ?? this.alarmTime,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      order: order ?? this.order,
      goalId: goalId ?? this.goalId,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      progressNotes: progressNotes ?? this.progressNotes,
      completedAt: completedAt ?? this.completedAt,
      seriesId: seriesId ?? this.seriesId,
      extendedDays: extendedDays ?? this.extendedDays,
      repeatDays: repeatDays ?? List.from(this.repeatDays),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'title': title,
      'description': description,
      'isDone': isDone,
      'is_completed': isDone,
      'status': status.name,
      'endDate': endDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'alarmTime': alarmTime?.toIso8601String(),
      'alarm_time': alarmTime?.toIso8601String(),
      'hasAlarm': hasAlarm,
      'has_alarm': hasAlarm,
      'order': order,
      'order_index': order,
      'goalId': goalId,
      'goal_id': goalId,
      'deletedAt': deletedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'progressNotes': progressNotes,
      'progress_notes': progressNotes,
      'progressStatus': progressNotes,
      'progress_status': progressNotes,
      'completedAt': completedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'seriesId': seriesId,
      'series_id': seriesId,
      'extensionSeriesId': seriesId,
      'extension_series_id': seriesId,
      'extendedDays': extendedDays,
      'extended_days': extendedDays,
      'extendedDaysCount': extendedDays,
      'extended_days_count': extendedDays,
      'repeatDays': repeatDays,
      'repeat_days': repeatDays,
    };
  }

  /// Exact database contract for Supabase `tasks` table
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'is_completed': isDone || status == TaskStatus.completed,
      'is_done': isDone || status == TaskStatus.completed,
      'completed_at': completedAt?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'has_alarm': hasAlarm,
      'alarm_time': alarmTime?.toIso8601String(),
      'goal_id': goalId,
      'order_index': order,
      'repeat_days': repeatDays,
      'progress_status': progressNotes,
      'progress_notes': progressNotes,
      'series_id': seriesId,
      'extension_series_id': seriesId,
      'extended_days': extendedDays,
      'extended_days_count': extendedDays,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
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
      isDone: map['isDone'] ?? map['is_completed'] ?? false,
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['scheduledDate'] ?? map['end_date']),
      alarmTime: parseDate(map['alarmTime'] ?? map['alarm_time']),
      hasAlarm: map['hasAlarm'] ?? map['alarmEnabled'] ?? map['has_alarm'] ?? false,
      order: map['order'] ?? map['order_index'] ?? 0,
      goalId: map['goalId'] ?? map['goal_id'],
      deletedAt: parseDate(map['deletedAt'] ?? map['deleted_at']),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
      progressNotes: (map['progressNotes'] ??
              map['progress_notes'] ??
              map['progressStatus'] ??
              map['progress_status'] ??
              '')
          .toString(),
      completedAt: parseDate(map['completedAt'] ?? map['completed_at']),
      seriesId: (map['seriesId'] ??
              map['series_id'] ??
              map['extensionSeriesId'] ??
              map['extension_series_id']) as String?,
      extendedDays: (map['extendedDays'] ??
              map['extended_days'] ??
              map['extendedDaysCount'] ??
              map['extended_days_count']) as int?,
      repeatDays: map['repeatDays'] != null
          ? List<int>.from(map['repeatDays'])
          : (map['repeat_days'] != null ? List<int>.from(map['repeat_days']) : const []),
    );
  }
}
