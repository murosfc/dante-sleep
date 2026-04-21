import 'dart:ui';

import 'package:intl/intl.dart';

class SleepEntry {
  DateTime? wokeUp;
  DateTime? slept;
  bool isDay;
  bool bottle;

  SleepEntry({this.wokeUp, this.slept, this.isDay = true, this.bottle = false});

  Map<String, dynamic> toJson() => {
    'wokeUp': wokeUp?.toIso8601String(),
    'slept': slept?.toIso8601String(),
    'isDay': isDay,
    'bottle': bottle,
  };

  factory SleepEntry.fromJson(Map<String, dynamic> json) => SleepEntry(
    wokeUp: json['wokeUp'] != null ? DateTime.parse(json['wokeUp']) : null,
    slept: json['slept'] != null ? DateTime.parse(json['slept']) : null,
    isDay: json['isDay'] ?? true,
    bottle: json['bottle'] ?? false,
  );

  String getFormattedWokeUp(Locale locale, bool is24Hour) {
    if (wokeUp == null) return '';
    String pattern = is24Hour ? 'dd-MMM HH:mm' : 'dd-MMM h:mm a';
    return DateFormat(
      pattern,
      locale.languageCode == 'pt' ? 'pt_BR' : 'en',
    ).format(wokeUp!);
  }

  String getFormattedSlept(Locale locale, bool is24Hour) {
    if (slept == null) return '';
    String pattern = is24Hour ? 'dd-MMM HH:mm' : 'dd-MMM h:mm a';
    return DateFormat(
      pattern,
      locale.languageCode == 'pt' ? 'pt_BR' : 'en',
    ).format(slept!);
  }

  String getSleepTime(List<SleepEntry> allEntries, int index) {
    if (wokeUp == null) return '-';
    for (int i = index - 1; i >= 0; i--) {
      if (allEntries[i].slept != null) {
        Duration diff = wokeUp!.difference(allEntries[i].slept!);
        return '${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
      }
    }
    return '-';
  }

  String getAwakeTime(List<SleepEntry> allEntries, int index) {
    if (slept == null) return '-';
    for (int i = index - 1; i >= 0; i--) {
      if (allEntries[i].wokeUp != null) {
        Duration diff = slept!.difference(allEntries[i].wokeUp!);
        return '${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
      }
    }
    return '-';
  }
}
