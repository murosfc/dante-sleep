import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'dante_sleep_ai';
  static const _channelName = 'AI Sleep Suggestions';
  static const int _napNotifId = 1001;
  static const int _bedtimeNotifId = 1002;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Request permissions (call after user consents).
  static Future<bool> requestPermissions() async {
    // Android 13+
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;

    // iOS
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;

    return granted || iosGranted;
  }

  /// Schedule a local notification for [napTime] and/or [bedtimeRoutineStart].
  /// Times are in "HH:mm" format.
  static Future<void> scheduleAiSuggestions({
    required String? napTime,
    required String? napRationale,
    required String? routineStart,
    required String? routineRationale,
    required bool isPt,
  }) async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();

    if (napTime != null) {
      final scheduled = _parseToday(napTime, now);
      if (scheduled != null && scheduled.isAfter(now)) {
        await _schedule(
          id: _napNotifId,
          title: isPt ? '🍼 Hora da soneca!' : '🍼 Nap time!',
          body: napRationale ?? napTime,
          scheduledTime: scheduled,
        );
      }
    }

    if (routineStart != null) {
      final scheduled = _parseToday(routineStart, now);
      if (scheduled != null && scheduled.isAfter(now)) {
        await _schedule(
          id: _bedtimeNotifId,
          title: isPt ? '🌙 Iniciar rotina noturna' : '🌙 Start bedtime routine',
          body: routineRationale ?? routineStart,
          scheduledTime: scheduled,
        );
      }
    }
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static DateTime? _parseToday(String hhmm, DateTime reference) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(reference.year, reference.month, reference.day, h, m);
  }
}
