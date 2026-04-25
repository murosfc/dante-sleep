import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SleepEntry {
  String? firestoreId; // ID do documento no Firestore
  DateTime? wokeUp;
  DateTime? slept;
  bool isDay;
  bool bottle;
  DateTime? bottleTime;
  bool isExpanded;
  String syncStatus; // 'synced', 'pending', 'failed'
  DateTime? createdAt;
  DateTime? updatedAt;

  SleepEntry({
    this.firestoreId,
    this.wokeUp,
    this.slept,
    this.isDay = true,
    this.bottle = false,
    this.bottleTime,
    this.isExpanded = true,
    this.syncStatus = 'synced',
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'wokeUp': wokeUp?.toIso8601String(),
    'slept': slept?.toIso8601String(),
    'isDay': isDay,
    'bottle': bottle,
    'bottleTime': bottleTime?.toIso8601String(),
    'isExpanded': isExpanded,
    'syncStatus': syncStatus,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> toFirestore() => {
    'wokeUp': wokeUp?.toIso8601String(),
    'slept': slept?.toIso8601String(),
    'isDay': isDay,
    'bottle': bottle,
    'bottleTime': bottleTime?.toIso8601String(),
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  factory SleepEntry.fromJson(Map<String, dynamic> json) => SleepEntry(
    firestoreId: json['firestoreId'],
    wokeUp: _parseDynamicDateTime(json['wokeUp']),
    slept: _parseDynamicDateTime(json['slept']),
    isDay: json['isDay'] ?? true,
    bottle: json['bottle'] ?? false,
    bottleTime: _parseDynamicDateTime(json['bottleTime']),
    isExpanded: json['isExpanded'] ?? true,
    syncStatus: json['syncStatus'] ?? 'synced',
    createdAt: _parseDynamicDateTime(json['createdAt']),
    updatedAt: _parseDynamicDateTime(json['updatedAt']),
  );

  factory SleepEntry.fromFirestore(Map<String, dynamic> json, String docId) => SleepEntry(
    firestoreId: docId,
    wokeUp: _parseDynamicDateTime(json['wokeUp']),
    slept: _parseDynamicDateTime(json['slept']),
    isDay: json['isDay'] ?? true,
    bottle: json['bottle'] ?? false,
    bottleTime: _parseDynamicDateTime(json['bottleTime']),
    isExpanded: true,
    syncStatus: 'synced',
    createdAt: _parseDynamicDateTime(json['createdAt']),
    updatedAt: _parseDynamicDateTime(json['updatedAt']),
  );

  static DateTime? _parseDynamicDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

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
    if (wokeUp == null || slept == null) return '-';
    Duration diff = wokeUp!.difference(slept!);
    if (diff.isNegative) return '-';
    return '${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
  }

  String getAwakeTime(List<SleepEntry> allEntries, int index) {
    if (wokeUp == null) return '-';
    if (index - 1 >= 0) {
      SleepEntry newerEntry = allEntries[index - 1];
      if (newerEntry.slept != null) {
        Duration diff = newerEntry.slept!.difference(wokeUp!);
        if (!diff.isNegative) {
          return '${diff.inHours}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}';
        }
      }
    }
    return '-';
  }

  String getFormattedBottleTime(Locale locale, bool is24Hour) {
    if (bottleTime == null) return '';
    String pattern = is24Hour ? 'HH:mm' : 'h:mm a';
    return DateFormat(
      pattern,
      locale.languageCode == 'pt' ? 'pt_BR' : 'en',
    ).format(bottleTime!);
  }
}
