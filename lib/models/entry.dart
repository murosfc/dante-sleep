import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SleepEntry {
  String? firestoreId; // ID do documento no Firestore

  // Stable client-side identity, independent of firestoreId. Lets the sync
  // queue correlate a queued 'update' back to this exact entry even when it
  // was created offline and doesn't have a firestoreId yet — without this,
  // an update queued before its paired create resolves permanently loses
  // track of which document to patch once the create finally syncs.
  final String localId;
  DateTime? wokeUp;
  DateTime? slept;
  bool isDay;
  bool bottle;
  DateTime? bottleTime;
  bool isExpanded;
  String syncStatus; // 'synced', 'pending', 'failed'
  DateTime? createdAt;
  DateTime? updatedAt;

  static int _localIdCounter = 0;
  static String _generateLocalId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_localIdCounter++}';

  SleepEntry({
    this.firestoreId,
    String? localId,
    this.wokeUp,
    this.slept,
    this.isDay = true,
    this.bottle = false,
    this.bottleTime,
    this.isExpanded = true,
    this.syncStatus = 'synced',
    this.createdAt,
    this.updatedAt,
  }) : localId = localId ?? _generateLocalId();

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

  /// Formats a duration as `H:MM`, or `H:MM:SS` while it's still live
  /// (ticking), so it's clear at a glance whether a value is frozen.
  static String _formatDuration(Duration diff, {required bool live}) {
    final hours = diff.inHours;
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    if (!live) return '$hours:$minutes';
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Time spent sleeping. If [now] is provided and this entry's sleep
  /// hasn't been closed yet (no [wokeUp]), returns the live elapsed time
  /// (with seconds) instead of '-', so the UI can show it advancing until
  /// a new record closes the cycle — at which point it freezes to `H:MM`.
  String getSleepTime(List<SleepEntry> allEntries, int index, {DateTime? now}) {
    if (slept == null) return '-';
    if (wokeUp == null) {
      if (now == null) return '-';
      Duration diff = now.difference(slept!);
      if (diff.isNegative) return '-';
      return _formatDuration(diff, live: true);
    }
    Duration diff = wokeUp!.difference(slept!);
    if (diff.isNegative) return '-';
    return _formatDuration(diff, live: false);
  }

  /// Time spent awake. If [now] is provided and this entry hasn't been
  /// followed by a newer sleep record yet, returns the live elapsed time
  /// (with seconds) instead of '-', so the UI can show it advancing until
  /// a new record closes the cycle — at which point it freezes to `H:MM`.
  String getAwakeTime(List<SleepEntry> allEntries, int index, {DateTime? now}) {
    if (wokeUp == null) return '-';
    if (index - 1 >= 0) {
      SleepEntry newerEntry = allEntries[index - 1];
      if (newerEntry.slept != null) {
        Duration diff = newerEntry.slept!.difference(wokeUp!);
        if (!diff.isNegative) {
          return _formatDuration(diff, live: false);
        }
      }
    }
    if (now != null) {
      Duration diff = now.difference(wokeUp!);
      if (!diff.isNegative) {
        return _formatDuration(diff, live: true);
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
