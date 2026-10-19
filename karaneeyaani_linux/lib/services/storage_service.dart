import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task_model.dart';
import '../models/goal_model.dart';

class StorageService {
  static const String _fileName = 'karaneeyaani_store.json';
  File? _file;

  Future<void> init() async {
    await _getFile();
  }

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    String basePath;
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      basePath = xdgDataHome;
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        basePath = '$home/.local/share';
      } else {
        final dir = await getApplicationSupportDirectory();
        basePath = dir.path;
      }
    }
    final dataDir = Directory('$basePath/karaneeyaani');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    _file = File('${dataDir.path}/$_fileName');
    return _file!;
  }

  Future<Map<String, dynamic>> _readRawData() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return {'tasks': [], 'goals': [], 'sync_queue': [], 'auth': null};
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {'tasks': [], 'goals': [], 'sync_queue': [], 'auth': null};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {'tasks': [], 'goals': [], 'sync_queue': [], 'auth': null};
    }
  }

  Future<void> _writeRawData(Map<String, dynamic> data) async {
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

  Future<List<TaskModel>> loadTasks({void Function(List<String> purgedCompletedIds)? onCompletedPurged}) async {
    final raw = await _readRawData();
    final list = raw['tasks'] as List? ?? [];
    final now = DateTime.now();
    final trashCutoff = now.subtract(const Duration(days: 5));
    final completedCutoff = now.subtract(const Duration(days: 20));

    final tasks = list.map((m) => TaskModel.fromMap(Map<String, dynamic>.from(m))).toList();
    final List<String> purgedCompleted = [];

    // Auto-prune:
    // 1. Trash older than 5 days
    // 2. Completed items reaching 20 continuous days in completed state
    final filtered = tasks.where((t) {
      if (t.status == TaskStatus.trashed && t.deletedAt != null) {
        return t.deletedAt!.isAfter(trashCutoff);
      }
      if (t.status == TaskStatus.completed) {
        final compDate = t.completedAt ?? t.updatedAt ?? t.createdAt ?? now;
        final isKept = compDate.isAfter(completedCutoff);
        if (!isKept) {
          purgedCompleted.add(t.id);
        }
        return isKept;
      }
      return true;
    }).toList();

    if (filtered.length != tasks.length) {
      await saveTasks(filtered);
      if (purgedCompleted.isNotEmpty && onCompletedPurged != null) {
        onCompletedPurged(purgedCompleted);
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

  // Sync Queue storage
  Future<List<Map<String, dynamic>>> loadSyncQueue() async {
    final raw = await _readRawData();
    final list = raw['sync_queue'] as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    final raw = await _readRawData();
    raw['sync_queue'] = queue;
    await _writeRawData(raw);
  }

  Future<void> addToSyncQueue(Map<String, dynamic> mutation) async {
    final queue = await loadSyncQueue();
    queue.add(mutation);
    await saveSyncQueue(queue);
  }

  // Auth cache in XDG storage
  Future<void> saveAuthData({
    required String username,
    required String userId,
    required String pinHash,
  }) async {
    final raw = await _readRawData();
    raw['auth'] = {
      'username': username,
      'userId': userId,
      'pinHash': pinHash,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _writeRawData(raw);
  }

  Future<Map<String, String>?> loadAuthData() async {
    final raw = await _readRawData();
    final auth = raw['auth'] as Map?;
    if (auth == null) return null;
    return {
      'username': auth['username']?.toString() ?? '',
      'userId': auth['userId']?.toString() ?? '',
      'pinHash': auth['pinHash']?.toString() ?? '',
    };
  }

  Future<void> clearAuthData() async {
    final raw = await _readRawData();
    raw.remove('auth');
    await _writeRawData(raw);
  }

  Future<void> clearAll() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
