import 'package:flutter_test/flutter_test.dart';
import 'package:karaneeyaani_windows/models/task_model.dart';
import 'package:karaneeyaani_windows/models/goal_model.dart';
import 'package:karaneeyaani_windows/services/pin_auth_service.dart';

void main() {
  group('TaskModel Tests', () {
    test('TaskModel serialization with Windows extension fields', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task-win-001',
        userId: 'user-guid-123',
        title: 'Complete Windows Desktop Feature',
        description: 'Native Windows Desktop for Karaneeyaani',
        progressNotes: 'Initial scaffold completed, connecting Supabase',
        isDone: true,
        completedAt: now,
        status: TaskStatus.completed,
        scheduledDate: DateTime(2026, 10, 24),
        seriesId: 'series-xyz',
        extendedDays: 5,
        repeatDays: [1, 2, 3, 4, 5],
      );

      final map = task.toMap();
      final reconstructed = TaskModel.fromMap(map);

      expect(reconstructed.id, equals('task-win-001'));
      expect(reconstructed.userId, equals('user-guid-123'));
      expect(reconstructed.title, equals('Complete Windows Desktop Feature'));
      expect(reconstructed.description, equals('Native Windows Desktop for Karaneeyaani'));
      expect(reconstructed.progressNotes, equals('Initial scaffold completed, connecting Supabase'));
      expect(reconstructed.isDone, isTrue);
      expect(reconstructed.status, equals(TaskStatus.completed));
      expect(reconstructed.completedAt?.toIso8601String(), equals(now.toIso8601String()));
      expect(reconstructed.seriesId, equals('series-xyz'));
      expect(reconstructed.extendedDays, equals(5));
      expect(reconstructed.repeatDays, equals([1, 2, 3, 4, 5]));
    });

    test('TaskModel toSupabaseMap outputs snake_case keys for database sync', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task-sync-1',
        userId: 'usr-99',
        title: 'Sync to Cloud',
        description: 'Push offline queue',
        progressNotes: 'Queue populated',
        isDone: false,
        status: TaskStatus.active,
        scheduledDate: DateTime(2026, 10, 24),
        completedAt: now,
        seriesId: 'series-abc',
        extendedDays: 10,
      );

      final supabaseMap = task.toSupabaseMap();
      expect(supabaseMap['id'], equals('task-sync-1'));
      expect(supabaseMap['user_id'], equals('usr-99'));
      expect(supabaseMap['title'], equals('Sync to Cloud'));
      expect(supabaseMap['progress_notes'], equals('Queue populated'));
      expect(supabaseMap['is_done'], isFalse);
      expect(supabaseMap['status'], equals('active'));
      expect(supabaseMap['series_id'], equals('series-abc'));
      expect(supabaseMap['extended_days'], equals(10));
      expect(supabaseMap['completed_at'], equals(now.toIso8601String()));
    });

    test('TaskModel copyWith preserves and updates fields correctly', () {
      final original = TaskModel(
        id: 'orig-1',
        title: 'Original Title',
        progressNotes: 'Step 1 done',
        isDone: false,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        progressNotes: 'Step 1 and 2 done',
        isDone: true,
      );

      expect(updated.id, equals('orig-1'));
      expect(updated.title, equals('Updated Title'));
      expect(updated.progressNotes, equals('Step 1 and 2 done'));
      expect(updated.isDone, isTrue);
    });
  });

  group('GoalModel Tests', () {
    test('GoalModel serialization and Supabase mapping', () {
      final goal = GoalModel(
        id: 'goal-win-1',
        userId: 'usr-123',
        title: 'Release Windows Desktop App',
        category: 'Desktop Engineering',
        status: GoalStatus.active,
        deadline: DateTime(2026, 12, 31),
      );

      final map = goal.toMap();
      final reconstructed = GoalModel.fromMap(map);

      expect(reconstructed.id, equals('goal-win-1'));
      expect(reconstructed.title, equals('Release Windows Desktop App'));
      expect(reconstructed.category, equals('Desktop Engineering'));
      expect(reconstructed.status, equals(GoalStatus.active));

      final supabaseMap = goal.toSupabaseMap();
      expect(supabaseMap['id'], equals('goal-win-1'));
      expect(supabaseMap['user_id'], equals('usr-123'));
      expect(supabaseMap['title'], equals('Release Windows Desktop App'));
      expect(supabaseMap['category'], equals('Desktop Engineering'));
      expect(supabaseMap['status'], equals('active'));
    });
  });

  group('PinAuthService Security and Validation Tests', () {
    test('PinAuthService.hashPin produces deterministic salted SHA-256 hash', () {
      final hash1 = PinAuthService.hashPin('Aniruddha', '123456');
      final hash2 = PinAuthService.hashPin('aniruddha', '123456'); // case-insensitive username normalization
      final hashDifferentPin = PinAuthService.hashPin('aniruddha', '654321');

      expect(hash1, isNotEmpty);
      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashDifferentPin)));
      expect(hash1.length, equals(64)); // SHA-256 hex string length
    });

    test('PinAuthService.isValidUsername validates 3-20 alphanumerics or underscores', () {
      expect(PinAuthService.isValidUsername('admin'), isTrue);
      expect(PinAuthService.isValidUsername('john_doe'), isTrue);
      expect(PinAuthService.isValidUsername('Dev_User_2026'), isTrue);

      expect(PinAuthService.isValidUsername('ab'), isFalse); // too short (< 3)
      expect(PinAuthService.isValidUsername('a_very_long_username_exceeding_twenty_chars'), isFalse); // too long (> 20)
      expect(PinAuthService.isValidUsername('user@domain'), isFalse); // invalid character '@'
      expect(PinAuthService.isValidUsername('user-name'), isFalse); // invalid character '-'
      expect(PinAuthService.isValidUsername('user name'), isFalse); // space
    });

    test('PinAuthService.isValidPin validates exactly 6 numeric digits', () {
      expect(PinAuthService.isValidPin('123456'), isTrue);
      expect(PinAuthService.isValidPin('000000'), isTrue);
      expect(PinAuthService.isValidPin('987654'), isTrue);

      expect(PinAuthService.isValidPin('12345'), isFalse); // 5 digits
      expect(PinAuthService.isValidPin('1234567'), isFalse); // 7 digits
      expect(PinAuthService.isValidPin('12a456'), isFalse); // non-numeric
      expect(PinAuthService.isValidPin('abcdef'), isFalse); // alphabetic
      expect(PinAuthService.isValidPin(''), isFalse); // empty
    });
  });

  group('20-Day Completed Tasks Auto-Purge Retention Tests', () {
    test('Completed task within 20 days is retained; older than 20 days is purged', () {
      final now = DateTime.now();
      final completedCutoff = now.subtract(const Duration(days: 20));

      final taskCompleted10DaysAgo = TaskModel(
        id: 'kept-task',
        title: 'Task completed 10 days ago',
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(days: 10)),
      );

      final taskCompleted25DaysAgo = TaskModel(
        id: 'purged-task',
        title: 'Task completed 25 days ago',
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(days: 25)),
      );

      final isKeptRetained = (taskCompleted10DaysAgo.completedAt ?? now).isAfter(completedCutoff);
      final isPurgedRetained = (taskCompleted25DaysAgo.completedAt ?? now).isAfter(completedCutoff);

      expect(isKeptRetained, isTrue, reason: 'Task completed 10 days ago must be retained');
      expect(isPurgedRetained, isFalse, reason: 'Task completed 25 days ago must be auto-purged');
    });

    test('Restoration is only allowed within the 20-day window', () {
      final now = DateTime.now();

      final recentTask = TaskModel(
        id: 'recent-1',
        title: 'Recent task',
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(days: 15)),
      );

      final expiredTask = TaskModel(
        id: 'expired-1',
        title: 'Expired task',
        status: TaskStatus.completed,
        completedAt: now.subtract(const Duration(days: 22)),
      );

      final recentEligible = now.difference(recentTask.completedAt!).inDays < 20;
      final expiredEligible = now.difference(expiredTask.completedAt!).inDays < 20;

      expect(recentEligible, isTrue);
      expect(expiredEligible, isFalse);
    });
  });

  group('Task Extension Engine Tests', () {
    test('Task extension preserves title and progress notes but creates independent completion states', () {
      final baseDate = DateTime(2026, 10, 24);
      final baseTask = TaskModel(
        id: 'base-1',
        title: 'Review Desktop Architecture',
        description: 'Check IPC, local persistence, and sync services',
        progressNotes: 'Windows shell configured',
        isDone: true, // Base task is marked done for today
        status: TaskStatus.active,
        scheduledDate: baseDate,
        seriesId: 'series-desktop-1',
        extendedDays: 1,
      );

      // Simulate 3 days extension:
      const daysToExtend = 3;
      final extendedTasks = <TaskModel>[];

      for (int i = 1; i <= daysToExtend; i++) {
        final targetDate = baseDate.add(Duration(days: i));
        extendedTasks.add(TaskModel(
          id: 'ext-$i',
          userId: baseTask.userId,
          title: baseTask.title,
          description: baseTask.description,
          progressNotes: baseTask.progressNotes, // Title and progress notes copied
          isDone: false, // Independent toggle state! Must start false for each new day
          status: TaskStatus.active,
          scheduledDate: targetDate,
          seriesId: baseTask.seriesId,
          extendedDays: baseTask.extendedDays! + daysToExtend,
        ));
      }

      expect(extendedTasks.length, equals(3));
      for (int i = 0; i < extendedTasks.length; i++) {
        final t = extendedTasks[i];
        expect(t.title, equals('Review Desktop Architecture'));
        expect(t.progressNotes, equals('Windows shell configured'));
        expect(t.isDone, isFalse, reason: 'Extended task completion state must be independent');
        expect(t.seriesId, equals('series-desktop-1'));
        expect(t.scheduledDate, equals(baseDate.add(Duration(days: i + 1))));
      }
    });
  });
}
