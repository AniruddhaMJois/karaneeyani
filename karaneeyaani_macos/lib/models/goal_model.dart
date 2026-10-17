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
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'endDate': endDate?.toIso8601String(),
      'selectedDates': selectedDates.map((d) => d.toIso8601String()).toList(),
      'order': order,
      'deletedAt': deletedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
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
    if (map['selectedDates'] is List) {
      for (var item in map['selectedDates']) {
        final dt = parseDate(item);
        if (dt != null) parsedDates.add(dt);
      }
    }

    return GoalModel(
      id: docId ?? map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      status: parseStatus(map['status']),
      endDate: parseDate(map['endDate'] ?? map['deadline']),
      selectedDates: parsedDates,
      order: map['order'] ?? 0,
      deletedAt: parseDate(map['deletedAt']),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
