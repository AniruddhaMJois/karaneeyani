import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static String? localAlarmAudioPath;

  static Future<void> init() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Request permissions
    await _requestPermissions();

    // Download audio file
    await _downloadAlarmAudio();
  }

  static Future<void> _requestPermissions() async {
    // We request notification and exact alarm permissions
    if (Platform.isAndroid) {
      await [
        Permission.notification,
        Permission.scheduleExactAlarm,
        Permission.systemAlertWindow,
        Permission.ignoreBatteryOptimizations,
      ].request();
    }
  }

  static Future<void> _downloadAlarmAudio() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloaded_alarm.ogg');

      if (await file.exists()) {
        localAlarmAudioPath = file.path;
        return;
      }

      // Fetch a reliable public domain alarm tone
      final response = await http.get(Uri.parse(
          'https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg'));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        localAlarmAudioPath = file.path;
        debugPrint('Alarm audio downloaded to: ${file.path}');
      } else {
        debugPrint('Failed to download alarm audio. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading alarm audio: $e');
    }
  }

  static Future<void> schedulePreAlarmNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pre_alarm_channel',
          'Pre-Alarm Notifications',
          channelDescription: 'Notifications shown 5 minutes before tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }
}
