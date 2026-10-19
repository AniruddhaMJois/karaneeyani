import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import 'storage_service.dart';

class SupabaseSyncService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xekveefmrwszyvkmhxvy.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhla3ZlZWZtcndzenl2a21oeHZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MTkyODYsImV4cCI6MjEwNzk5NTI4Nn0.4inVz6rbqwyfwkfzCNQGv8qZFb5JIpsZ3ZrvpmRkKhI',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization skipped or offline: $e');
    }
  }

  /// Check if active network connectivity is available
  static Future<bool> hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }

  final StorageService _storage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  static SupabaseSyncService? _instance;

  factory SupabaseSyncService({StorageService? storage}) {
    _instance ??= SupabaseSyncService._internal(storage ?? StorageService());
    return _instance!;
  }

  SupabaseSyncService._internal(this._storage) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline) {
          debugPrint('Network connection restored. Syncing offline queue to Supabase...');
          processQueue();
        }
      });
    } catch (e) {
      debugPrint('Error attaching connectivity listener: $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Enqueue a task create/update mutation
  Future<void> enqueueTaskUpsert(TaskModel task) async {
    await _storage.addToSyncQueue({
      'action': 'UPSERT_TASK',
      'id': task.id,
      'data': {
        'id': task.id,
        'user_id': task.userId,
        'title': task.title,
        'description': task.description,
        'status': task.status.name,
        'is_completed': task.status == TaskStatus.completed || task.isDone,
        'completed_at': task.completedAt?.toIso8601String(),
        'end_date': task.endDate?.toIso8601String(),
        'has_alarm': task.hasAlarm,
        'alarm_time': task.alarmTime?.toIso8601String(),
        'goal_id': task.goalId,
        'order_index': task.order,
        'repeat_days': task.repeatDays,
        'progress_notes': task.progressNotes,
        'progress_status': task.progressNotes,
        'series_id': task.seriesId,
        'extension_series_id': task.seriesId,
        'extended_days': task.extendedDays,
        'extended_days_count': task.extendedDays,
        'created_at': (task.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (task.updatedAt ?? DateTime.now()).toIso8601String(),
        'deleted_at': task.deletedAt?.toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  /// Enqueue permanent task deletion
  Future<void> enqueueTaskDelete(String taskId) async {
    await _storage.addToSyncQueue({
      'action': 'DELETE_TASK',
      'id': taskId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  /// Enqueue a goal create/update mutation
  Future<void> enqueueGoalUpsert(GoalModel goal) async {
    await _storage.addToSyncQueue({
      'action': 'UPSERT_GOAL',
      'id': goal.id,
      'data': {
        'id': goal.id,
        'user_id': goal.userId,
        'title': goal.title,
        'description': goal.description,
        'category': goal.category,
        'status': goal.status.name,
        'deadline': goal.deadline?.toIso8601String(),
        'end_date': goal.deadline?.toIso8601String(),
        'order_index': goal.order,
        'created_at': (goal.createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (goal.updatedAt ?? DateTime.now()).toIso8601String(),
        'deleted_at': goal.deletedAt?.toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  /// Enqueue permanent goal deletion
  Future<void> enqueueGoalDelete(String goalId) async {
    await _storage.addToSyncQueue({
      'action': 'DELETE_GOAL',
      'id': goalId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  /// Process pending local queue mutations to Supabase
  Future<void> processQueue() async {
    if (_isProcessing) return;
    final isOnline = await hasInternetConnection();
    if (!isOnline) return;

    final sc = client;
    if (sc == null) return;

    _isProcessing = true;
    try {
      final queue = await _storage.loadSyncQueue();
      if (queue.isEmpty) return;

      final remaining = List<Map<String, dynamic>>.from(queue);
      for (final item in queue) {
        final action = item['action'] as String?;
        final id = item['id'] as String?;

        try {
          if (action == 'UPSERT_TASK' && item['data'] != null) {
            await sc.from('tasks').upsert(item['data']);
            remaining.remove(item);
          } else if (action == 'DELETE_TASK' && id != null) {
            await sc.from('tasks').delete().eq('id', id);
            remaining.remove(item);
          } else if (action == 'UPSERT_GOAL' && item['data'] != null) {
            await sc.from('goals').upsert(item['data']);
            remaining.remove(item);
          } else if (action == 'DELETE_GOAL' && id != null) {
            await sc.from('goals').delete().eq('id', id);
            remaining.remove(item);
          }
        } catch (e) {
          debugPrint('Sync mutation failed for $action ($id): $e');
          // On network/auth error, preserve remaining queue items
          break;
        }
      }

      await _storage.saveSyncQueue(remaining);
    } catch (e) {
      debugPrint('Error executing sync queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Pull remote tasks for user and merge
  Future<void> syncDownTasks(String userId) async {
    final sc = client;
    if (sc == null) return;

    final isOnline = await hasInternetConnection();
    if (!isOnline) return;

    try {
      final response = await sc.from('tasks').select().eq('user_id', userId);
      final List<dynamic> remoteList = response as List<dynamic>;
      if (remoteList.isEmpty) return;

      final localTasks = await _storage.loadTasks();
      final localMap = {for (var t in localTasks) t.id: t};

      for (var r in remoteList) {
        final remoteMap = Map<String, dynamic>.from(r as Map);
        final remoteTask = TaskModel.fromMap(remoteMap);
        final local = localMap[remoteTask.id];

        if (local == null) {
          localMap[remoteTask.id] = remoteTask;
        } else {
          final remoteUpdated = remoteTask.updatedAt ?? remoteTask.createdAt ?? DateTime(2000);
          final localUpdated = local.updatedAt ?? local.createdAt ?? DateTime(2000);
          if (remoteUpdated.isAfter(localUpdated)) {
            localMap[remoteTask.id] = remoteTask;
          }
        }
      }

      await _storage.saveTasks(localMap.values.toList());
    } catch (e) {
      debugPrint('Failed to sync down tasks: $e');
    }
  }
}
