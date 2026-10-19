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
      'data': task.toSupabaseMap(),
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
      'data': goal.toSupabaseMap(),
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

  /// Pull remote goals for user and merge
  Future<void> syncDownGoals(String userId) async {
    final sc = client;
    if (sc == null) return;

    final isOnline = await hasInternetConnection();
    if (!isOnline) return;

    try {
      final response = await sc.from('goals').select().eq('user_id', userId);
      final List<dynamic> remoteList = response as List<dynamic>;
      if (remoteList.isEmpty) return;

      final localGoals = await _storage.loadGoals();
      final localMap = {for (var g in localGoals) g.id: g};

      for (var r in remoteList) {
        final remoteMap = Map<String, dynamic>.from(r as Map);
        final remoteGoal = GoalModel.fromMap(remoteMap);
        final local = localMap[remoteGoal.id];

        if (local == null) {
          localMap[remoteGoal.id] = remoteGoal;
        } else {
          final remoteUpdated = remoteGoal.updatedAt ?? remoteGoal.createdAt ?? DateTime(2000);
          final localUpdated = local.updatedAt ?? local.createdAt ?? DateTime(2000);
          if (remoteUpdated.isAfter(localUpdated)) {
            localMap[remoteGoal.id] = remoteGoal;
          }
        }
      }

      await _storage.saveGoals(localMap.values.toList());
    } catch (e) {
      debugPrint('Failed to sync down goals: $e');
    }
  }

  /// Full synchronization (flushes offline queue, pulls remote tasks and goals)
  Future<void> syncAll(String userId) async {
    await processQueue();
    if (userId.isNotEmpty && userId != 'local_user') {
      await syncDownTasks(userId);
      await syncDownGoals(userId);
    }
  }
}
