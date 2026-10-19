enum GoalStatus { active, completed, trashed }

class GoalModel {
  String id;
  String userId;
  String title;
  String description;
  String category;
  GoalStatus status;
  DateTime? endDate;
  List<DateTime> selectedDates;
  int order;
  DateTime? deletedAt;
  DateTime? createdAt;
  DateTime? updatedAt;

  DateTime? get deadline => endDate;
  set deadline(DateTime? val) => endDate = val;

  GoalModel({
    required this.id,
    this.userId = '',
    required this.title,
    this.description = '',
    this.category = '',
    this.status = GoalStatus.active,
    DateTime? endDate,
    DateTime? deadline,
    this.selectedDates = const [],
    this.order = 0,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  }) : endDate = deadline ?? endDate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'endDate': endDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'selectedDates': selectedDates.map((d) => d.toIso8601String()).toList(),
      'selected_dates': selectedDates.map((d) => d.toIso8601String()).toList(),
      'order': order,
      'order_index': order,
      'deletedAt': deletedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Exact database contract for Supabase `goals` table
  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'end_date': endDate?.toIso8601String(),
      'selected_dates': selectedDates.map((d) => d.toIso8601String()).toList(),
      'order_index': order,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    GoalStatus parseStatus(dynamic s) {
      if (s == 'completed') return GoalStatus.completed;
      if (s == 'trashed') return GoalStatus.trashed;
      return GoalStatus.active;
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    List<DateTime> parsedDates = [];
    final rawDates = map['selectedDates'] ?? map['selected_dates'];
    if (rawDates is List) {
      for (var item in rawDates) {
        final dt = parseDate(item);
        if (dt != null) parsedDates.add(dt);
      }
    }

    return GoalModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['end_date'] ?? map['deadline']),
      selectedDates: parsedDates,
      order: map['order'] ?? map['order_index'] ?? 0,
      deletedAt: parseDate(map['deletedAt'] ?? map['deleted_at']),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }
}
