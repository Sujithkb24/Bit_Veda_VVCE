// lib/services/alarm_service.dart
//
// KEY CHANGE from previous version:
//   • The notification is now SILENT (playSound: false, enableVibration: false)
//   • AlarmOverlayScreen handles ALL audio via just_audio (looping until dismissed)
//   • This prevents the "beeps once then stops" problem caused by the system
//     playing the notification sound while just_audio was also starting up

import 'dart:convert';
import 'dart:typed_data';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/schedule_model.dart';
import 'pill_count_service.dart';

// ── TOP-LEVEL ALARM CALLBACK ──────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> alarmCallback(int alarmId) async {
  // Initialize Firebase in this isolate
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    print('alarmCallback: Firebase init error: $e');
  }

  // Load metadata
  final prefs = await SharedPreferences.getInstance();
  final metaJson = prefs.getString('alarm_meta_$alarmId');

  String containerId = 'Unknown';
  String deviceId    = '';
  String userId      = '';
  String scheduleId  = '';
  int    timeIndex   = 0;
  int    dosePerTime = 1;
  List<String> allTimes = [];
  DateTime endDate = DateTime.now().add(const Duration(days: 30));

  if (metaJson != null) {
    final meta = jsonDecode(metaJson) as Map<String, dynamic>;
    containerId = meta['containerId'] ?? 'Unknown';
    deviceId    = meta['deviceId']    ?? '';
    userId      = meta['userId']      ?? '';
    scheduleId  = meta['scheduleId']  ?? '';
    timeIndex   = meta['timeIndex']   ?? 0;
    dosePerTime = meta['dosePerTime'] ?? 1;
    allTimes    = List<String>.from(meta['scheduleTimes'] ?? []);
    endDate     = DateTime.parse(meta['endDate'] ??
        DateTime.now().add(const Duration(days: 30)).toIso8601String());
  }

  if (DateTime.now().isAfter(endDate)) {
    await prefs.remove('alarm_meta_$alarmId');
    return;
  }

  // ── Deduct pills immediately when this alarm/dispense event fires ─────────
  // Uses per-container dosePerTime saved in alarm metadata.
  if (deviceId.trim().isNotEmpty &&
      containerId.trim().isNotEmpty &&
      userId.trim().isNotEmpty &&
      dosePerTime > 0) {
    try {
      await PillCountService.deductDoseStatic(
        deviceId: deviceId.trim(),
        containerId: containerId.trim(),
        userId: userId.trim(),
        dosePerTime: dosePerTime,
      );
      print(
        'alarmCallback: deducted $dosePerTime for container $containerId',
      );
    } catch (e) {
      print('alarmCallback: pill deduction error: $e');
    }
  }

  // ── Show notification ─────────────────────────────────────────────────────
  // IMPORTANT:
  // - We use an "insistent" alarm notification so the SYSTEM keeps repeating
  //   the alarm sound until the user acts (Taken/Snooze).
  // - This avoids relying on in-app audio (which cannot be started reliably
  //   from a background isolate / when the app is killed).
  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
      const InitializationSettings(android: androidInit));

  // Create (or upgrade to) an audible alarm channel.
  // Channel settings are sticky on Android, so we use a new ID to ensure
  // devices that previously created a silent channel will now play sound.
  const channel = AndroidNotificationChannel(
    'medicine_alarm_channel_v2',
    'Medicine Alarms',
    description: 'Medication reminders (rings until dismissed)',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final androidDetails = AndroidNotificationDetails(
    'medicine_alarm_channel_v2',
    'Medicine Alarms',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,       // ← launches AlarmActivity on lock screen
    category: AndroidNotificationCategory.alarm,
    ongoing: true,                // stays in tray until dismissed
    autoCancel: false,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    // FLAG_INSISTENT (4): repeat sound/vibrate until the user acts.
    // https://developer.android.com/reference/android/app/Notification#FLAG_INSISTENT
    additionalFlags: Int32List.fromList(<int>[4]),
    styleInformation: BigTextStyleInformation(
      'Container $containerId — Take $dosePerTime pill(s) now.\nTap to open.',
      summaryText: 'Medication Reminder',
    ),
    actions: [
      const AndroidNotificationAction('taken', 'Taken',
          showsUserInterface: true, cancelNotification: true),
      const AndroidNotificationAction('snooze', 'Snooze 10 min',
          showsUserInterface: false, cancelNotification: true),
    ],
  );

  await notifications.show(
    alarmId,
    'Time to take your medicine',
    'Container $containerId · $dosePerTime pill(s)',
    NotificationDetails(android: androidDetails),
    payload: jsonEncode({
      'alarmId':        alarmId,
      'medicationName': containerId,
      'doseInfo':       '$dosePerTime pill(s)',
    }),
  );

  print('alarmCallback: notification shown for container $containerId');

  // ── Reschedule for tomorrow ───────────────────────────────────────────────
  if (allTimes.isNotEmpty && timeIndex < allTimes.length) {
    final timeStr      = allTimes[timeIndex];
    final nextAlarmTime = _nextOccurrence(timeStr, addDays: 1);

    if (nextAlarmTime.isBefore(endDate)) {
      await AndroidAlarmManager.oneShotAt(
        nextAlarmTime,
        alarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
      print('alarmCallback: rescheduled for tomorrow at $timeStr');
    }
  }
}

DateTime _nextOccurrence(String timeStr, {int addDays = 0}) {
  final parts  = timeStr.trim().split(':');
  final hour   = int.tryParse(parts[0]) ?? 8;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final now    = DateTime.now();
  return DateTime(now.year, now.month, now.day + addDays, hour, minute);
}

// ── ALARM SERVICE ─────────────────────────────────────────────────────────────
class AlarmService {
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  Future<void> scheduleAlarmsForSchedule(
    MedicationSchedule schedule, {
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await cancelAlarmsForSchedule(schedule.id);

    for (int i = 0; i < schedule.scheduleTimes.length; i++) {
      final timeStr = schedule.scheduleTimes[i];
      final alarmId = _alarmId(schedule.id, i);

      DateTime alarmTime = _nextOccurrence(timeStr);
      if (alarmTime.isBefore(DateTime.now())) {
        alarmTime = _nextOccurrence(timeStr, addDays: 1);
      }

      final meta = jsonEncode({
        'scheduleId':    schedule.id,
        'timeIndex':     i,
        'containerId':   schedule.containerId,
        'deviceId':      schedule.deviceId,
        'userId':        userId,
        'dosePerTime':   schedule.dosePerTime,
        'scheduleTimes': schedule.scheduleTimes,
        'endDate':       schedule.endDate.toIso8601String(),
      });
      await prefs.setString('alarm_meta_$alarmId', meta);

      final success = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarmId,
        alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
      print('Alarm ${success ? "set" : "FAILED"}: '
          'container=${schedule.containerId}, time=$timeStr, fires=$alarmTime');
    }

    final ids = List.generate(
        schedule.scheduleTimes.length, (i) => _alarmId(schedule.id, i));
    await prefs.setString('alarm_ids_${schedule.id}', jsonEncode(ids));
  }

  Future<void> cancelAlarmsForSchedule(String scheduleId) async {
    final prefs   = await SharedPreferences.getInstance();
    final idsJson = prefs.getString('alarm_ids_$scheduleId');
    if (idsJson == null) return;
    final ids = (jsonDecode(idsJson) as List).cast<int>();
    for (final id in ids) {
      await AndroidAlarmManager.cancel(id);
      await prefs.remove('alarm_meta_$id');
    }
    await prefs.remove('alarm_ids_$scheduleId');
  }

  // Test alarm — fires in 5 seconds, no pill deduction
  Future<void> fireTestAlarm() async {
    const testAlarmId = 99999;
    final prefs = await SharedPreferences.getInstance();
    final meta = jsonEncode({
      'scheduleId':    'TEST',
      'timeIndex':     0,
      'containerId':   'A1 (TEST)',
      'deviceId':      '',
      'userId':        '',
      'dosePerTime':   1,
      'scheduleTimes': ['TEST'],
      'endDate':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    await prefs.setString('alarm_meta_$testAlarmId', meta);
    await AndroidAlarmManager.oneShotAt(
      DateTime.now().add(const Duration(seconds: 5)),
      testAlarmId,
      alarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
    );
  }

  Future<void> fetchAndScheduleFromCloud(
    String deviceId, {
    required String userId,
  }) async {
    const baseUrl =
        'https://us-central1-smart-medicine-dispenser-efa5b.cloudfunctions.net/getSchedule';
    try {
      final response = await http
          .get(Uri.parse('$baseUrl?deviceId=$deviceId'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final body          = jsonDecode(response.body) as Map<String, dynamic>;
      final schedulesJson = body['schedules'] as List<dynamic>? ?? [];

      for (final s in schedulesJson) {
        final map        = s as Map<String, dynamic>;
        final endDateStr = map['endDate'] as String?;
        final endDate    = endDateStr != null
            ? DateTime.tryParse(endDateStr) ??
                DateTime.now().add(const Duration(days: 30))
            : DateTime.now().add(const Duration(days: 30));
        if (endDate.isBefore(DateTime.now())) continue;

        final schedule = MedicationSchedule(
          id:            map['id'] ?? '',
          deviceId:      deviceId,
          containerId:   map['containerId'] ?? '',
          dosePerTime:   (map['dosePerTime'] as num?)?.toInt() ?? 1,
          scheduleTimes: List<String>.from(map['scheduleTimes'] ?? []),
          endDate:       endDate,
          createdAt:     DateTime.now(),
          updatedAt:     DateTime.now(),
        );
        await scheduleAlarmsForSchedule(schedule, userId: userId);
      }
    } catch (e) {
      print('fetchAndScheduleFromCloud error: $e');
    }
  }

  AlarmInfo? getNextAlarm(List<MedicationSchedule> schedules) {
    DateTime? earliest;
    String?   container;
    for (final schedule in schedules) {
      for (final timeStr in schedule.scheduleTimes) {
        var t = _nextOccurrence(timeStr);
        if (t.isBefore(DateTime.now())) t = _nextOccurrence(timeStr, addDays: 1);
        if (earliest == null || t.isBefore(earliest)) {
          earliest  = t;
          container = schedule.containerId;
        }
      }
    }
    if (earliest == null) return null;
    return AlarmInfo(time: earliest, containerId: container ?? '');
  }

  static int _alarmId(String scheduleId, int timeIndex) {
    final hash = scheduleId.hashCode.abs();
    return (hash + timeIndex * 1000003) & 0x7FFFFFFF;
  }
}

class AlarmInfo {
  final DateTime time;
  final String   containerId;
  AlarmInfo({required this.time, required this.containerId});
}