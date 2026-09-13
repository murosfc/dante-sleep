import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const MethodChannel _exactAlarmsChannel = MethodChannel(
    'com.example.dante_sleep/exact_alarms',
  );
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'dante_sleep_ai';
  static const _channelName = 'AI Sleep Suggestions';
  static const int _napNotifId = 1001;
  static const int _bedtimeNotifId = 1002;
  static const int _nightWakeNotifId = 1003;

  /// Manual-plan nap notifications occupy ids [_manualNapBaseId] .. +N.
  static const int _manualNapBaseId = 1100;

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
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission() ?? false;

    // iOS
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
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
    required String? nightWakeTime,
    required String? nightWakeRationale,
    required bool isPt,
    String? userName,
    String? babyName,
    String? babySex,
  }) async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();

    if (nightWakeTime != null) {
      final scheduled = _parseToday(nightWakeTime, now);
      if (scheduled != null && scheduled.isAfter(now)) {
        await _schedule(
          id: _nightWakeNotifId,
          title: _nightWakeTitle(isPt: isPt, babyName: babyName, babySex: babySex),
          body: _composeBody(
            isPt: isPt,
            userName: userName,
            babyName: babyName,
            babySex: babySex,
            rationale: nightWakeRationale,
            fallbackTime: nightWakeTime,
          ),
          scheduledTime: scheduled,
        );
      }
      return;
    }

    if (napTime != null) {
      final scheduled = _parseToday(napTime, now);
      if (scheduled != null && scheduled.isAfter(now)) {
        await _schedule(
          id: _napNotifId,
          title: _napTitle(isPt: isPt, babyName: babyName, babySex: babySex),
          body: _composeBody(
            isPt: isPt,
            userName: userName,
            babyName: babyName,
            babySex: babySex,
            rationale: napRationale,
            fallbackTime: napTime,
          ),
          scheduledTime: scheduled,
        );
      }
    }

    if (routineStart != null) {
      final scheduled = _parseToday(routineStart, now);
      if (scheduled != null && scheduled.isAfter(now)) {
        await _schedule(
          id: _bedtimeNotifId,
          title: _routineTitle(
            isPt: isPt,
            babyName: babyName,
            babySex: babySex,
          ),
          body: _composeBody(
            isPt: isPt,
            userName: userName,
            babyName: babyName,
            babySex: babySex,
            rationale: routineRationale,
            fallbackTime: routineStart,
          ),
          scheduledTime: scheduled,
        );
      }
    }
  }

  /// Schedules the manual (AI-free) sleep plan: one notification per upcoming
  /// nap start plus one for the night routine. [napStarts] and [routineStart]
  /// are absolute times for today; anything already in the past is skipped.
  static Future<void> scheduleManualPlan({
    required List<DateTime> napStarts,
    required DateTime? routineStart,
    required int totalNaps,
    required bool isPt,
    String? userName,
    String? babyName,
    String? babySex,
  }) async {
    await initialize();
    await cancelAll();

    final now = DateTime.now();

    for (var i = 0; i < napStarts.length; i++) {
      final start = napStarts[i];
      if (!start.isAfter(now)) continue;
      // napStarts holds only the still-upcoming naps; recover the human nap
      // number (1-based) from how many are left.
      final napNumber = totalNaps - napStarts.length + i + 1;
      await _schedule(
        id: _manualNapBaseId + i,
        title: _napTitle(isPt: isPt, babyName: babyName, babySex: babySex),
        body: _composeBody(
          isPt: isPt,
          userName: userName,
          babyName: babyName,
          babySex: babySex,
          rationale: _manualNapRationale(
            isPt: isPt,
            napNumber: napNumber,
            totalNaps: totalNaps,
          ),
          fallbackTime: _formatHm(start),
        ),
        scheduledTime: start,
      );
    }

    if (routineStart != null && routineStart.isAfter(now)) {
      await _schedule(
        id: _bedtimeNotifId,
        title: _routineTitle(isPt: isPt, babyName: babyName, babySex: babySex),
        body: _composeBody(
          isPt: isPt,
          userName: userName,
          babyName: babyName,
          babySex: babySex,
          rationale: isPt
              ? 'Hora de iniciar o ritual do sono da noite.'
              : 'Time to start the bedtime routine.',
          fallbackTime: _formatHm(routineStart),
        ),
        scheduledTime: routineStart,
      );
    }
  }

  static String _manualNapRationale({
    required bool isPt,
    required int napNumber,
    required int totalNaps,
  }) {
    return isPt
        ? 'Soneca $napNumber de $totalNaps do dia.'
        : 'Nap $napNumber of $totalNaps for the day.';
  }

  static String _formatHm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _napTitle({
    required bool isPt,
    String? babyName,
    String? babySex,
  }) {
    final babyNameTrimmed = babyName?.trim() ?? '';
    final hasBaby = babyNameTrimmed.isNotEmpty;
    if (isPt) {
      return hasBaby
          ? '🍼 Hora da soneca de $babyNameTrimmed!'
          : '🍼 Hora da soneca ${_ptPossessiveBaby(babySex)}!';
    }
    return hasBaby ? '🍼 $babyNameTrimmed\'s nap time!' : '🍼 Nap time!';
  }

  static String _routineTitle({
    required bool isPt,
    String? babyName,
    String? babySex,
  }) {
    final babyNameTrimmed = babyName?.trim() ?? '';
    final hasBaby = babyNameTrimmed.isNotEmpty;
    if (isPt) {
      return hasBaby
          ? '🌙 Iniciar rotina noturna de $babyNameTrimmed'
          : '🌙 Iniciar rotina noturna ${_ptPossessiveBaby(babySex)}';
    }
    return hasBaby
        ? '🌙 Start $babyNameTrimmed\'s bedtime routine'
        : '🌙 Start bedtime routine';
  }

  static String _nightWakeTitle({required bool isPt, String? babyName, String? babySex}) {
    final hasBaby = babyName != null && babyName.trim().isNotEmpty;
    if (isPt) {
      return hasBaby
          ? '🌅 Previsão de acordar de ${babyName.trim()}'
          : '🌅 Previsão de acordar ${_ptPossessiveBaby(babySex)}';
    }
    return hasBaby
        ? '🌅 ${babyName.trim()} wake-up forecast'
        : '🌅 Baby wake-up forecast';
  }

  static String _composeBody({
    required bool isPt,
    required String? userName,
    required String? babyName,
    required String? babySex,
    required String? rationale,
    required String fallbackTime,
  }) {
    final trimmedUser = userName?.trim();
    final trimmedBaby = babyName?.trim();
    final hasBabyName = trimmedBaby != null && trimmedBaby.isNotEmpty;
    final intro = (trimmedUser != null && trimmedUser.isNotEmpty)
        ? (isPt ? '$trimmedUser, ' : '$trimmedUser, ')
        : '';
    final defaultText = hasBabyName
        ? (isPt
              ? 'momento de cuidar do sono de $trimmedBaby.'
              : 'time to care for $trimmedBaby\'s sleep.')
        : (isPt
              ? 'momento de cuidar do sono ${_ptPossessiveBaby(babySex)}.'
              : 'time to care for your baby\'s sleep.');
    final content = (rationale != null && rationale.trim().isNotEmpty)
        ? rationale.trim()
        : fallbackTime;
    if (content.isEmpty) return '$intro$defaultText'.trim();

    if (isPt && !hasBabyName) {
      return '$intro${_ptDirectBaby(babySex)}: $content'.trim();
    }

    return '$intro$content'.trim();
  }

  static String _ptPossessiveBaby(String? babySex) {
    return babySex == 'female' ? 'da sua bebê' : 'do seu bebê';
  }

  static String _ptDirectBaby(String? babySex) {
    return babySex == 'female' ? 'sua bebê' : 'seu bebê';
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<bool> _supportsExactAlarms() async {
    try {
      final result = await _exactAlarmsChannel.invokeMethod<bool>(
        'canScheduleExactAlarms',
      );
      return result == true;
    } catch (_) {
      return false;
    }
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
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final useExactAlarms = await _supportsExactAlarms();
    if (!useExactAlarms) {
      debugPrint(
        'Exact alarms not supported or permitted; using inexact scheduling.',
      );
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: useExactAlarms
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexact,
      );
    } on PlatformException catch (e) {
      debugPrint('Notification scheduling failed: ${e.code} ${e.message}');
      if (useExactAlarms) {
        debugPrint('Retrying with inexact scheduling.');
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledTime, tz.local),
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexact,
        );
      }
    }
  }

  static DateTime? _parseToday(String hhmm, DateTime reference) {
    final regex = RegExp(r'(\d{1,2}):(\d{2})');
    final match = regex.firstMatch(hhmm);
    if (match == null) return null;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null) return null;
    return DateTime(reference.year, reference.month, reference.day, h, m);
  }
}
