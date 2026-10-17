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
    final dir = await getApplicationSupportDirectory();
    final dataDir = Directory('${dir.path}/karaneeyaani');
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
        return {'tasks': [], 'goals': []};
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {'tasks': [], 'goals': []};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return {'tasks': [], 'goals': []};
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

  Future<List<TaskModel>> loadTasks() async {
    final raw = await _readRawData();
    final list = raw['tasks'] as List? ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 5));

    final tasks = list.map((m) => TaskModel.fromMap(Map<String, dynamic>.from(m))).toList();
    // Auto-prune trash older than 5 days
    final filtered = tasks.where((t) {
      if (t.status == TaskStatus.trashed && t.deletedAt != null) {
        return t.deletedAt!.isAfter(cutoff);
      }
      return true;
    }).toList();

    if (filtered.length != tasks.length) {
      await saveTasks(filtered);
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

  Future<void> clearAll() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}
