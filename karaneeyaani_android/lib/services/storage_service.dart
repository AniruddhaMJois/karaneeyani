import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class StorageService {
  static const String _fileName = 'karaneeyaani_store.json';
  File? _file;

  Future<void> init() async {
    if (!kIsWeb) {
      await _getFile();
    }
  }

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${dir.path}/karaneeyaani');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    _file = File('${dataDir.path}/$_fileName');
    return _file!;
  }

  Future<Map<String, dynamic>> _readRawData() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_fileName);
        if (content == null || content.trim().isEmpty) return {'tasks': [], 'goals': []};
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        return {'tasks': [], 'goals': []};
      }
    }
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return {'tasks': [], 'goals': []};
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {'tasks': [], 'goals': []};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {'tasks': [], 'goals': []};
    }
  }

  Future<void> _writeRawData(Map<String, dynamic> data) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fileName, jsonEncode(data));
      } catch (_) {}
      return;
    }
    try {
      final file = await _getFile();
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(data), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {}
  }

  /// Purges tasks that have been in completed state for 20 continuous days or more
  static List<TaskModel> purgeExpiredCompletedTasks(List<TaskModel> tasks, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final completedCutoff = currentTime.subtract(const Duration(days: 20));
    return tasks.where((t) {
      if (t.status == TaskStatus.completed && t.completedAt != null) {
        if (t.completedAt!.isBefore(completedCutoff)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<List<TaskModel>> loadTasks() async {
    final raw = await _readRawData();
    final list = raw['tasks'] as List? ?? [];
    final trashCutoff = DateTime.now().subtract(const Duration(days: 5));
    final completedCutoff = DateTime.now().subtract(const Duration(days: 20));

    final tasks = list.map((m) => TaskModel.fromMap(Map<String, dynamic>.from(m))).toList();
    final List<String> purgedTaskIds = [];

    // Auto-prune trash older than 5 days, and completed tasks older than 20 days
    final filtered = tasks.where((t) {
      if (t.status == TaskStatus.trashed && t.deletedAt != null) {
        if (!t.deletedAt!.isAfter(trashCutoff)) {
          purgedTaskIds.add(t.id);
          return false;
        }
      }
      if (t.status == TaskStatus.completed && t.completedAt != null) {
        if (t.completedAt!.isBefore(completedCutoff)) {
          purgedTaskIds.add(t.id);
          return false;
        }
      }
      return true;
    }).toList();

    if (filtered.length != tasks.length) {
      await saveTasks(filtered);
      for (final id in purgedTaskIds) {
        await addToSyncQueue({
          'action': 'DELETE_TASK',
          'id': id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    return filtered;
  }

  Future<List<GoalModel>> loadGoals() async {
    final raw = await _readRawData();
    final list = raw['goals'] as List? ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 5));

    final goals = list.map((m) => GoalModel.fromMap(Map<String, dynamic>.from(m))).toList();
    final filtered = goals.where((g) {
      if (g.status == GoalStatus.trashed && g.deletedAt != null) {
        return g.deletedAt!.isAfter(cutoff);
      }
      return true;
    }).toList();

    if (filtered.length != goals.length) {
      await saveGoals(filtered);
    }

    return filtered;
  }

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final raw = await _readRawData();
    raw['tasks'] = tasks.map((t) => t.toMap()).toList();
    await _writeRawData(raw);
  }

  Future<void> saveGoals(List<GoalModel> goals) async {
    final raw = await _readRawData();
    raw['goals'] = goals.map((g) => g.toMap()).toList();
    await _writeRawData(raw);
  }

  // --- SYNC QUEUE PERSISTENCE ---

  Future<List<Map<String, dynamic>>> loadSyncQueue() async {
    final raw = await _readRawData();
    final list = raw['sync_queue'] as List? ?? [];
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    final raw = await _readRawData();
    raw['sync_queue'] = queue;
    await _writeRawData(raw);
  }

  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final queue = await loadSyncQueue();
    // Replace existing mutation for same ID if matching
    final id = item['id'];
    if (id != null) {
      queue.removeWhere((q) => q['id'] == id && q['action'] == item['action']);
    }
    queue.add(item);
    await saveSyncQueue(queue);
  }

  Future<void> removeFromSyncQueue(String id) async {
    final queue = await loadSyncQueue();
    queue.removeWhere((q) => q['id'] == id);
    await saveSyncQueue(queue);
  }

  Future<void> clearAll() async {
    await _writeRawData({'tasks': [], 'goals': [], 'sync_queue': []});
  }
}
