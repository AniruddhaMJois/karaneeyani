import 'package:flutter_test/flutter_test.dart';
import 'package:karaneeyaani_linux/models/task_model.dart';
import 'package:karaneeyaani_linux/models/goal_model.dart';
import 'package:karaneeyaani_linux/services/pin_auth_service.dart';

void main() {
  group('TaskModel Tests', () {
    test('TaskModel serialization test', () {
      final completedTime = DateTime(2026, 10, 8, 14, 30);
      final task = TaskModel(
        id: 'test-123',
        title: 'Complete Linux App',
        description: 'Native Linux Desktop for Karaneeyaani',
        isDone: false,
        status: TaskStatus.active,
        scheduledDate: DateTime(2026, 10, 8),
        progressNotes: 'Implemented dual storage',
        completedAt: completedTime,
        seriesId: 'series-abc',
        extendedDays: 5,
      );

      final map = task.toMap();
      final reconstructed = TaskModel.fromMap(map);

      expect(reconstructed.id, equals('test-123'));
      expect(reconstructed.title, equals('Complete Linux App'));
      expect(reconstructed.isDone, isFalse);
      expect(reconstructed.status, equals(TaskStatus.active));
      expect(reconstructed.progressNotes, equals('Implemented dual storage'));
      expect(reconstructed.completedAt, equals(completedTime));
      expect(reconstructed.seriesId, equals('series-abc'));
      expect(reconstructed.extendedDays, equals(5));
      expect(reconstructed.progressStatus, equals('Implemented dual storage'));
      expect(reconstructed.extensionSeriesId, equals('series-abc'));
      expect(reconstructed.extendedDaysCount, equals(5));
    });

    test('TaskModel copyWith test', () {
      final task = TaskModel(
        id: 'task-1',
        title: 'Original Title',
        isDone: false,
        progressNotes: 'Initial note',
      );

      final updated = task.copyWith(
        title: 'Updated Title',
        isDone: true,
        progressNotes: 'Updated progress note',
        completedAt: DateTime(2026, 10, 19),
        seriesId: 'series-xyz',
        extendedDays: 10,
      );

      expect(updated.id, equals('task-1'));
      expect(updated.title, equals('Updated Title'));
      expect(updated.isDone, isTrue);
      expect(updated.progressNotes, equals('Updated progress note'));
      expect(updated.seriesId, equals('series-xyz'));
      expect(updated.extendedDays, equals(10));
    });

    test('TaskModel toSupabaseMap matches exact table contract', () {
      final task = TaskModel(
        id: 't-123',
        userId: 'u-456',
        title: 'Contract Test',
        description: 'Testing exact Supabase schema',
        status: TaskStatus.active,
        isDone: false,
        progressNotes: 'Testing contract',
        seriesId: 'series-uuid',
        extendedDays: 5,
        repeatDays: [1, 2, 3],
      );

      final map = task.toSupabaseMap();

      expect(map['id'], equals('t-123'));
      expect(map['user_id'], equals('u-456'));
      expect(map['title'], equals('Contract Test'));
      expect(map['description'], equals('Testing exact Supabase schema'));
      expect(map['status'], equals('active'));
      expect(map['is_completed'], isFalse);
      expect(map['progress_status'], equals('Testing contract'));
      expect(map['extension_series_id'], equals('series-uuid'));
      expect(map['extended_days_count'], equals(5));
      expect(map['repeat_days'], equals([1, 2, 3]));
      expect(map.containsKey('progress_notes'), isFalse);
      expect(map.containsKey('series_id'), isFalse);
      expect(map.containsKey('extended_days'), isFalse);
    });
  });

  group('GoalModel Tests', () {
    test('GoalModel serialization test', () {
      final goal = GoalModel(
        id: 'goal-456',
        userId: 'user-789',
        title: 'Release Desktop App',
        category: 'Work',
        status: GoalStatus.active,
        endDate: DateTime(2026, 12, 31),
        selectedDates: [DateTime(2026, 12, 1), DateTime(2026, 12, 2)],
        order: 2,
      );

      final map = goal.toMap();
      final reconstructed = GoalModel.fromMap(map);

      expect(reconstructed.id, equals('goal-456'));
      expect(reconstructed.userId, equals('user-789'));
      expect(reconstructed.title, equals('Release Desktop App'));
      expect(reconstructed.category, equals('Work'));
      expect(reconstructed.status, equals(GoalStatus.active));
      expect(reconstructed.selectedDates.length, equals(2));
      expect(reconstructed.order, equals(2));
    });

    test('GoalModel toSupabaseMap matches exact table contract', () {
      final goal = GoalModel(
        id: 'goal-456',
        userId: 'u-789',
        title: 'Release Desktop App',
        category: 'Work',
        status: GoalStatus.active,
        endDate: DateTime(2026, 12, 31),
        selectedDates: [DateTime(2026, 12, 1)],
        order: 1,
      );

      final map = goal.toSupabaseMap();

      expect(map['id'], equals('goal-456'));
      expect(map['user_id'], equals('u-789'));
      expect(map['title'], equals('Release Desktop App'));
      expect(map['category'], equals('Work'));
      expect(map['status'], equals('active'));
      expect(map['end_date'], isNotNull);
      expect(map['selected_dates'], isA<List>());
      expect(map['order_index'], equals(1));
      expect(map.containsKey('deadline'), isFalse);
    });
  });

  group('PinAuthService Validation & Hashing Tests', () {
    test('Username validation rules', () {
      expect(PinAuthService.isValidUsername('aniruddha_jois'), isTrue);
      expect(PinAuthService.isValidUsername('user123'), isTrue);
      expect(PinAuthService.isValidUsername('abc'), isTrue);
      expect(PinAuthService.isValidUsername('user_name_20'), isTrue);

      // Invalid
      expect(PinAuthService.isValidUsername('ab'), isFalse); // Too short (< 3)
      expect(PinAuthService.isValidUsername('a_very_long_username_over_20_chars'), isFalse); // > 20
      expect(PinAuthService.isValidUsername('user name'), isFalse); // Contains space
      expect(PinAuthService.isValidUsername('user@name'), isFalse); // Special character
      expect(PinAuthService.isValidUsername('user!'), isFalse);
    });

    test('6-Digit PIN validation rules', () {
      expect(PinAuthService.isValidPin('123456'), isTrue);
      expect(PinAuthService.isValidPin('000000'), isTrue);
      expect(PinAuthService.isValidPin('987654'), isTrue);

      // Invalid
      expect(PinAuthService.isValidPin('12345'), isFalse); // 5 digits
      expect(PinAuthService.isValidPin('1234567'), isFalse); // 7 digits
      expect(PinAuthService.isValidPin('12345a'), isFalse); // Non-digit
      expect(PinAuthService.isValidPin(''), isFalse);
    });

    test('Deterministic salted PIN hash generation', () {
      final hash1 = PinAuthService.hashPin('aniruddha_jois', '123456');
      final hash2 = PinAuthService.hashPin('aniruddha_jois', '123456');
      final hashDiffUser = PinAuthService.hashPin('other_user', '123456');
      final hashDiffPin = PinAuthService.hashPin('aniruddha_jois', '654321');

      expect(hash1, equals(hash2));
      expect(hash1, isNotEmpty);
      expect(hash1.length, equals(64)); // SHA-256 hex string length
      expect(hash1, isNot(equals(hashDiffUser)));
      expect(hash1, isNot(equals(hashDiffPin)));
    });
  });

  group('20-Day Retention Check Tests', () {
    test('Task completed >= 20 days ago qualifies for auto-purge', () {
      final now = DateTime(2026, 10, 19, 12, 0);
      final completed21DaysAgo = now.subtract(const Duration(days: 21));
      final completed19DaysAgo = now.subtract(const Duration(days: 19));

      final oldTask = TaskModel(
        id: 'old-task',
        title: 'Old Completed Task',
        isDone: true,
        completedAt: completed21DaysAgo,
      );

      final freshTask = TaskModel(
        id: 'fresh-task',
        title: 'Fresh Completed Task',
        isDone: true,
        completedAt: completed19DaysAgo,
      );

      final shouldPurgeOld = oldTask.completedAt != null &&
          now.difference(oldTask.completedAt!).inDays >= 20;
      final shouldPurgeFresh = freshTask.completedAt != null &&
          now.difference(freshTask.completedAt!).inDays >= 20;

      expect(shouldPurgeOld, isTrue);
      expect(shouldPurgeFresh, isFalse);
    });
  });
}
