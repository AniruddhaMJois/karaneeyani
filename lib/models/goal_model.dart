import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalStatus { active, completed, trashed }

class GoalModel {
  String id;
  String userId;
  String title;
  String description;
  GoalStatus status;
  DateTime? createdAt;

  GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.status = GoalStatus.active,
    this.createdAt,
  });

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    
    GoalStatus parseStatus(String? statusStr) {
      if (statusStr == 'completed') return GoalStatus.completed;
      if (statusStr == 'trashed') return GoalStatus.trashed;
      return GoalStatus.active;
    }

    return GoalModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: parseStatus(data['status']),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
