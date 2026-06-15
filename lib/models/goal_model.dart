import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalStatus { active, completed, trashed }

class GoalModel {
  String id;
  String userId;
  String title;
  String description;
  GoalStatus status;
  DateTime? endDate;
  List<DateTime> selectedDates;
  DateTime? createdAt;
  int order;
  DateTime? deletedAt;

  GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.status = GoalStatus.active,
    this.endDate,
    this.selectedDates = const [],
    this.createdAt,
    this.order = 0,
    this.deletedAt,
  });

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    
    GoalStatus parseStatus(String? statusStr) {
      if (statusStr == 'completed') return GoalStatus.completed;
      if (statusStr == 'trashed') return GoalStatus.trashed;
      return GoalStatus.active;
    }

    List<DateTime> parsedSelectedDates = [];
    if (data['selectedDates'] != null) {
      parsedSelectedDates = (data['selectedDates'] as List)
          .map((t) => (t as Timestamp).toDate())
          .toList();
    } else if (data['endDate'] != null) {
      parsedSelectedDates = [(data['endDate'] as Timestamp).toDate()];
    }

    return GoalModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: parseStatus(data['status']),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      selectedDates: parsedSelectedDates,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      order: data['order'] ?? 0,
      deletedAt: data['deletedAt'] != null ? (data['deletedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'selectedDates': selectedDates.map((d) => Timestamp.fromDate(d)).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'order': order,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }
}
