import 'package:flutter_test/flutter_test.dart';
import 'package:karaneeyaani/models/task_model.dart';
import 'package:karaneeyaani/models/goal_model.dart';

void main() {
  test('TaskModel serialization test', () {
    final now = DateTime.now();
    final task = TaskModel(
      id: 'task-1',
      userId: 'local_user',
      title: 'Test Task',
      description: 'Testing offline task',
      status: TaskStatus.active,
      createdAt: now,
    );

    final map = task.toMap();
    expect(map['id'], 'task-1');
    expect(map['title'], 'Test Task');
    expect(map['status'], 'active');

    final reconstructed = TaskModel.fromMap(map);
    expect(reconstructed.id, 'task-1');
    expect(reconstructed.title, 'Test Task');
    expect(reconstructed.status, TaskStatus.active);
  });

  test('GoalModel serialization test', () {
    final now = DateTime.now();
    final goal = GoalModel(
      id: 'goal-1',
      userId: 'local_user',
      title: 'Test Goal',
      description: 'Testing offline goal',
      status: GoalStatus.active,
      createdAt: now,
    );

    final map = goal.toMap();
    expect(map['id'], 'goal-1');
    expect(map['title'], 'Test Goal');
    expect(map['status'], 'active');

    final reconstructed = GoalModel.fromMap(map);
    expect(reconstructed.id, 'goal-1');
    expect(reconstructed.title, 'Test Goal');
    expect(reconstructed.status, GoalStatus.active);
  });
}
