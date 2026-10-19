import 'package:flutter_test/flutter_test.dart';
import 'package:karaneeyaani_android/models/task_model.dart';
import 'package:karaneeyaani_android/models/goal_model.dart';
import 'package:karaneeyaani_android/services/pin_auth_service.dart';
import 'package:karaneeyaani_android/services/auth_service.dart';
import 'package:karaneeyaani_android/services/storage_service.dart';

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

  test('TaskModel with progress status and extension series serialization', () {
    final now = DateTime.now();
    final completedAt = now.subtract(const Duration(days: 3));
    final task = TaskModel(
      id: 'task-ext-1',
      userId: 'user_123',
      title: 'Extended Workout',
      description: 'Daily gym training',
      progressStatus: 'Completed 3 sets of bench press',
      status: TaskStatus.completed,
      isDone: true,
      completedAt: completedAt,
      extensionSeriesId: 'series-xyz',
      extendedDaysCount: 5,
      createdAt: now,
    );

    final map = task.toMap();
    expect(map['progressStatus'], 'Completed 3 sets of bench press');
    expect(map['extensionSeriesId'], 'series-xyz');
    expect(map['extendedDaysCount'], 5);
    expect(map['completedAt'], completedAt.toIso8601String());

    final reconstructed = TaskModel.fromMap(map);
    expect(reconstructed.progressStatus, 'Completed 3 sets of bench press');
    expect(reconstructed.extensionSeriesId, 'series-xyz');
    expect(reconstructed.extendedDaysCount, 5);
    expect(reconstructed.isDone, true);
    expect(reconstructed.completedAt?.day, completedAt.day);
  });

  test('Salted SHA-256 PIN hashing security test', () {
    const username = 'Warrior_01';
    const pin = '123456';

    final hash1 = PinAuthService.hashPin(username, pin);
    final hash2 = PinAuthService.hashPin('warrior_01', pin); // case insensitive username
    final differentPinHash = PinAuthService.hashPin(username, '654321');
    final differentUserHash = PinAuthService.hashPin('Warrior_02', pin);

    expect(hash1, isNotEmpty);
    expect(hash1, hash2, reason: 'Username casing should be normalized in salt');
    expect(hash1, isNot(differentPinHash), reason: 'Different PINs must have distinct hashes');
    expect(hash1, isNot(differentUserHash), reason: 'Different usernames must have distinct hashes due to salting');
  });

  test('AuthService username and PIN validation tests', () {
    // Username validation
    expect(AuthService.isValidUsername('john_doe'), true);
    expect(AuthService.isValidUsername('user123'), true);
    expect(AuthService.isValidUsername('a_b'), true); // 3 chars
    expect(AuthService.isValidUsername('12345678901234567890'), true); // 20 chars
    expect(AuthService.isValidUsername('ab'), false); // Too short (< 3)
    expect(AuthService.isValidUsername('user@domain'), false); // Invalid char '@'
    expect(AuthService.isValidUsername('user name'), false); // Spaces not allowed
    expect(AuthService.isValidUsername('123456789012345678901'), false); // Too long (> 20)

    // PIN validation (strictly 6 numeric digits)
    expect(AuthService.isValidPin('123456'), true);
    expect(AuthService.isValidPin('000000'), true);
    expect(AuthService.isValidPin('999999'), true);
    expect(AuthService.isValidPin('12345'), false); // 5 digits
    expect(AuthService.isValidPin('1234567'), false); // 7 digits
    expect(AuthService.isValidPin('12345a'), false); // Non-numeric
    expect(AuthService.isValidPin('abcdef'), false); // Letters
  });

  test('StorageService 20-Day Completed Auto-Purge test', () async {
    final now = DateTime.now();
    final freshTask = TaskModel(
      id: 'fresh-1',
      userId: 'test-user',
      title: 'Fresh completed task',
      description: 'Completed 2 days ago',
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 2)),
    );

    final expiredTask = TaskModel(
      id: 'expired-1',
      userId: 'test-user',
      title: 'Old completed task',
      description: 'Completed 21 days ago',
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 21)),
    );

    final activeOldTask = TaskModel(
      id: 'active-old-1',
      userId: 'test-user',
      title: 'Active old task',
      description: 'Created 30 days ago but never completed',
      status: TaskStatus.active,
      createdAt: now.subtract(const Duration(days: 30)),
    );

    final inputTasks = [freshTask, expiredTask, activeOldTask];
    final purgedTasks = StorageService.purgeExpiredCompletedTasks(inputTasks);

    // Expired task (21 days old) must be purged permanently
    expect(purgedTasks.any((t) => t.id == 'expired-1'), false);
    // Fresh completed task (< 20 days) must be retained
    expect(purgedTasks.any((t) => t.id == 'fresh-1'), true);
    // Active task must never be purged regardless of age
    expect(purgedTasks.any((t) => t.id == 'active-old-1'), true);
  });

  test('Task Extension engine logic and independent completion', () {
    final baseDate = DateTime(2026, 10, 20);
    final targetDates = [
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 21),
      DateTime(2026, 10, 22),
    ];

    final originalTask = TaskModel(
      id: 'orig-1',
      userId: 'user-ext',
      title: 'Daily High Intensity Workout',
      description: 'Push beyond limits',
      progressStatus: 'Pre-workout nutrition done',
      status: TaskStatus.active,
      isDone: false,
      endDate: baseDate,
    );

    final seriesId = 'series-test-${DateTime.now().millisecondsSinceEpoch}';
    final extendedTasks = targetDates.map((targetDate) {
      return originalTask.copyWith(
        id: 'ext-${targetDate.day}',
        endDate: targetDate,
        extensionSeriesId: seriesId,
        extendedDaysCount: targetDates.length,
        isDone: false,
        status: TaskStatus.active,
        completedAt: null,
      );
    }).toList();

    expect(extendedTasks.length, 3);
    // All tasks share the same extensionSeriesId and have extendedDaysCount == 3
    for (final task in extendedTasks) {
      expect(task.extensionSeriesId, seriesId);
      expect(task.extendedDaysCount, 3);
      expect(task.title, 'Daily High Intensity Workout');
      expect(task.progressStatus, 'Pre-workout nutrition done');
      expect(task.isDone, false);
    }

    // Independent completion simulation: mark day 1 completed
    extendedTasks[0] = extendedTasks[0].copyWith(
      isDone: true,
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
      progressStatus: 'Day 1 Done: 5km run completed',
    );

    expect(extendedTasks[0].isDone, true);
    expect(extendedTasks[0].status, TaskStatus.completed);
    expect(extendedTasks[0].progressStatus, 'Day 1 Done: 5km run completed');

    // Day 2 and Day 3 remain strictly independent and active
    expect(extendedTasks[1].isDone, false);
    expect(extendedTasks[1].status, TaskStatus.active);
    expect(extendedTasks[2].isDone, false);
    expect(extendedTasks[2].status, TaskStatus.active);
  });
}
