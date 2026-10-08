import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import 'database_service.dart';

class AlarmService extends ChangeNotifier {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService({DatabaseService? dbService}) {
    if (dbService != null) {
      _instance._bindDbService(dbService);
    }
    return _instance;
  }
  AlarmService._internal();

  final AudioPlayer _player = AudioPlayer();
  Timer? _tickerTimer;
  TaskModel? _currentlyRingingTask;
  bool _isPlaying = false;
  StreamSubscription? _tasksSubscription;

  final StreamController<TaskModel> _alarmStreamController = StreamController<TaskModel>.broadcast();
  Stream<TaskModel> get onAlarmFired => _alarmStreamController.stream;
  Stream<TaskModel> get onAlarmTriggered => onAlarmFired;

  void _bindDbService(DatabaseService db) {
    _tasksSubscription?.cancel();
    _tasksSubscription = db.allActiveTasks.listen(syncAlarms);
  }

  TaskModel? get currentlyRingingTask => _currentlyRingingTask;
  bool get isPlaying => _isPlaying;

  final List<TaskModel> _scheduledTasks = [];

  void init() {
    _player.setReleaseMode(ReleaseMode.loop);
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), _checkAlarms);
  }

  void syncAlarms(List<TaskModel> tasks) {
    _scheduledTasks.clear();
    final now = DateTime.now();
    for (var task in tasks) {
      if (task.hasAlarm && task.alarmTime != null && !task.isDone && task.alarmTime!.isAfter(now.subtract(const Duration(minutes: 1)))) {
        _scheduledTasks.add(task);
      }
    }
  }

  void _checkAlarms(Timer timer) {
    if (_isPlaying) return;
    final now = DateTime.now();

    for (var task in List<TaskModel>.from(_scheduledTasks)) {
      if (task.alarmTime != null &&
          task.alarmTime!.year == now.year &&
          task.alarmTime!.month == now.month &&
          task.alarmTime!.day == now.day &&
          task.alarmTime!.hour == now.hour &&
          task.alarmTime!.minute == now.minute &&
          task.alarmTime!.second <= now.second) {
        _triggerAlarm(task);
        _scheduledTasks.remove(task);
        break;
      }
    }
  }

  Future<void> _triggerAlarm(TaskModel task) async {
    _currentlyRingingTask = task;
    _isPlaying = true;
    notifyListeners();
    _alarmStreamController.add(task);

    try {
      await _player.play(AssetSource('alarm.wav'));
    } catch (_) {
      // Audio playback fallback
    }
  }

  Future<void> stopAlarm() async {
    _isPlaying = false;
    _currentlyRingingTask = null;
    try {
      await _player.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> snoozeAlarm(TaskModel task, {int minutes = 5}) async {
    await stopAlarm();
    task.alarmTime = DateTime.now().add(Duration(minutes: minutes));
    _scheduledTasks.add(task);
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _player.dispose();
    _alarmStreamController.close();
    super.dispose();
  }
}
