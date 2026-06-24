import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
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
      int stateStartTime = 0;

      if (entries.isNotEmpty) {
        final latest = entries[0];
        final pattern = is24Hour ? 'HH:mm' : 'h:mm a';
        final localeStr = isPt ? 'pt_BR' : 'en';
        await initializeDateFormatting(localeStr, null);
        
        final subject = babyName != null && babyName.trim().isNotEmpty 
            ? babyName.trim() 
            : (isPt ? 'O bebê' : 'Baby');

        if (latest.slept != null && latest.wokeUp == null) {
          // Sleeping
          isSleeping = true;
          stateStartTime = latest.slept!.millisecondsSinceEpoch;
          final formattedTime = DateFormat(pattern, localeStr).format(latest.slept!);
          statusLabel = isPt ? '$subject está dormindo desde as $formattedTime' : '$subject is sleeping since $formattedTime';
        } else {
          // Awake
          isSleeping = false;
          final awakeStart = latest.wokeUp ?? latest.updatedAt ?? DateTime.now();
          stateStartTime = awakeStart.millisecondsSinceEpoch;
          final formattedTime = DateFormat(pattern, localeStr).format(awakeStart);
          statusLabel = isPt ? '$subject está acordado desde as $formattedTime' : '$subject is awake since $formattedTime';
        }
      }

      final durationPrefix = isPt ? 'Há' : 'For';

      await HomeWidget.saveWidgetData<bool>('is_sleeping', isSleeping);
      await HomeWidget.saveWidgetData<String>('status_label', statusLabel);
      await HomeWidget.saveWidgetData<String>('duration_prefix', durationPrefix);
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
