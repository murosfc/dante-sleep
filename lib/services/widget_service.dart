import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';

class WidgetService {
  static Future<void> updateHomeScreenWidget({
    required List<SleepEntry> entries,
    required Locale locale,
    required bool is24Hour,
    String? babyName,
    required bool isLightTheme,
  }) async {
    try {
      final isPt = locale.languageCode == 'pt';
      bool isSleeping = false;
      String statusLabel = isPt ? 'Sem registros' : 'No entries';
      String statusSince = '';
      int stateStartTime = 0;

      if (entries.isNotEmpty) {
        final latest = entries[0];
        final pattern = is24Hour ? 'HH:mm' : 'h:mm a';
        final localeStr = isPt ? 'pt_BR' : 'en';
        final subject = babyName != null && babyName.trim().isNotEmpty 
            ? babyName.trim() 
            : (isPt ? 'O bebê' : 'Baby');

        if (latest.slept != null && latest.wokeUp == null) {
          // Sleeping
          isSleeping = true;
          statusLabel = isPt ? '$subject está dormindo há' : '$subject is sleeping for';
          stateStartTime = latest.slept!.millisecondsSinceEpoch;
          final formattedTime = DateFormat(pattern, localeStr).format(latest.slept!);
          statusSince = isPt ? 'desde as $formattedTime' : 'since $formattedTime';
        } else {
          // Awake
          isSleeping = false;
          statusLabel = isPt ? '$subject está acordado há' : '$subject is awake for';
          final awakeStart = latest.wokeUp ?? latest.updatedAt ?? DateTime.now();
          stateStartTime = awakeStart.millisecondsSinceEpoch;
          final formattedTime = DateFormat(pattern, localeStr).format(awakeStart);
          statusSince = isPt ? 'desde as $formattedTime' : 'since $formattedTime';
        }
      }

      await HomeWidget.saveWidgetData<bool>('is_sleeping', isSleeping);
      await HomeWidget.saveWidgetData<String>('status_label', statusLabel);
      await HomeWidget.saveWidgetData<String>('status_since', statusSince);
      await HomeWidget.saveWidgetData<String>('state_start_time', stateStartTime.toString());
      await HomeWidget.saveWidgetData<bool>('is_light_theme', isLightTheme);

      await HomeWidget.updateWidget(
        androidName: 'DanteSleepWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error updating home screen widget: $e');
    }
  }
}
