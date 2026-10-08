import 'package:flutter_test/flutter_test.dart';
import 'package:karaneeyaani_linux/models/task_model.dart';
import 'package:karaneeyaani_linux/models/goal_model.dart';

void main() {
  test('TaskModel serialization test', () {
    final task = TaskModel(
      id: 'test-123',
      title: 'Complete Linux App',
      description: 'Native Linux Desktop for Karaneeyaani',
      isDone: false,
      status: TaskStatus.active,
      scheduledDate: DateTime(2026, 10, 8),
    );

    final map = task.toMap();
    final reconstructed = TaskModel.fromMap(map);

    expect(reconstructed.id, equals('test-123'));
    expect(reconstructed.title, equals('Complete Linux App'));
    expect(reconstructed.isDone, isFalse);
    expect(reconstructed.status, equals(TaskStatus.active));
  });

  test('GoalModel serialization test', () {
    final goal = GoalModel(
      id: 'goal-456',
      title: 'Release Desktop App',
      category: 'Work',
      status: GoalStatus.active,
      deadline: DateTime(2026, 12, 31),
    );

    final map = goal.toMap();
    final reconstructed = GoalModel.fromMap(map);

    expect(reconstructed.id, equals('goal-456'));
    expect(reconstructed.title, equals('Release Desktop App'));
    expect(reconstructed.category, equals('Work'));
    expect(reconstructed.status, equals(GoalStatus.active));
  });
}
