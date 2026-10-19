import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';
import 'storage_service.dart';
import 'supabase_service.dart';

class SyncService {
  final StorageService _storage;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  static SyncService? _instance;

  factory SyncService({StorageService? storage}) {
    _instance ??= SyncService._internal(storage ?? StorageService());
    return _instance!;
  }

  SyncService._internal(this._storage) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        final isOnline = results.any((r) => r != ConnectivityResult.none);
        if (isOnline) {
          debugPrint('Network connected. Processing offline sync queue...');
          processQueue();
        }
      });
    } catch (e) {
      debugPrint('Error setting up connectivity listener: $e');
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

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
        'is_completed': task.status == TaskStatus.completed,
        'completed_at': task.completedAt?.toIso8601String(),
        'end_date': task.endDate?.toIso8601String(),
        'has_alarm': task.hasAlarm,
        'alarm_time': task.alarmTime?.toIso8601String(),
        'goal_id': task.goalId,
        'order_index': task.order,
        'repeat_days': task.repeatDays,
        'progress_status': task.progressStatus,
        'extension_series_id': task.extensionSeriesId,
        'extended_days_count': task.extendedDaysCount,
        'created_at': task.createdAt?.toIso8601String(),
        'updated_at': task.updatedAt?.toIso8601String(),
        'deleted_at': task.deletedAt?.toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    // Trigger sync attempt in background
    unawaited(processQueue());
  }

  Future<void> enqueueTaskDelete(String taskId) async {
    await _storage.addToSyncQueue({
      'action': 'DELETE_TASK',
      'id': taskId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

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
        'end_date': goal.endDate?.toIso8601String(),
        'selected_dates': goal.selectedDates.map((d) => d.toIso8601String()).toList(),
        'order_index': goal.order,
        'created_at': goal.createdAt?.toIso8601String(),
        'updated_at': goal.updatedAt?.toIso8601String(),
        'deleted_at': goal.deletedAt?.toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  Future<void> enqueueGoalDelete(String goalId) async {
    await _storage.addToSyncQueue({
      'action': 'DELETE_GOAL',
      'id': goalId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    unawaited(processQueue());
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    final isOnline = await SupabaseService.hasInternetConnection();
    if (!isOnline) return;

    final client = SupabaseService.client;
    if (client == null) return;

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
            await client.from('tasks').upsert(item['data']);
            remaining.remove(item);
          } else if (action == 'DELETE_TASK' && id != null) {
            await client.from('tasks').delete().eq('id', id);
            remaining.remove(item);
          } else if (action == 'UPSERT_GOAL' && item['data'] != null) {
            await client.from('goals').upsert(item['data']);
            remaining.remove(item);
          } else if (action == 'DELETE_GOAL' && id != null) {
            await client.from('goals').delete().eq('id', id);
            remaining.remove(item);
          }
        } catch (e) {
          debugPrint('Sync mutation failed for $action ($id): $e');
          // If network error occurred, keep remaining and break
          break;
        }
      }

      await _storage.saveSyncQueue(remaining);
    } catch (e) {
      debugPrint('Error processing sync queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> syncDownTasks(String userId) async {
    final client = SupabaseService.client;
    if (client == null) return;

    final isOnline = await SupabaseService.hasInternetConnection();
    if (!isOnline) return;

    try {
      final response = await client.from('tasks').select().eq('user_id', userId);
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
          // Compare updated timestamps
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
