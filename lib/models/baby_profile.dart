import 'package:cloud_firestore/cloud_firestore.dart';

import '../knowledge/sleep_knowledge_base.dart';

class BabyProfile {
  String? name;
  DateTime? birthdate;
  String sex; // 'male' | 'female'
  String feedingType; // 'breast' | 'formula' | 'mixed'
  bool complementaryFoodStarted;
  int nightRoutineMinutes;
  int? targetBedtimeHour;
  int? targetBedtimeMinute;

  // Custom wake window (time awake between waking up and the next nap),
  // in minutes. Null means "use the age-based guideline as fallback".
  int? wakeWindowMinMinutes;
  int? wakeWindowMaxMinutes;

  // Custom nap duration (how long a nap typically lasts), in minutes.
  // Null means "use the age-based guideline as fallback".
  int? napDurationMinMinutes;
  int? napDurationMaxMinutes;

  BabyProfile({
    this.name,
    this.birthdate,
    this.sex = 'male',
    this.feedingType = 'breast',
    this.complementaryFoodStarted = false,
    this.nightRoutineMinutes = 30,
    this.targetBedtimeHour,
    this.targetBedtimeMinute,
    this.wakeWindowMinMinutes,
    this.wakeWindowMaxMinutes,
    this.napDurationMinMinutes,
    this.napDurationMaxMinutes,
  });

  /// Wake window in hours, using the custom value if set, otherwise the
  /// age-based guideline.
  ({double minHours, double maxHours}) get effectiveWakeWindowHours {
    if (wakeWindowMinMinutes != null && wakeWindowMaxMinutes != null) {
      return (
        minHours: wakeWindowMinMinutes! / 60.0,
        maxHours: wakeWindowMaxMinutes! / 60.0,
      );
    }
    return SleepKnowledgeBase.getWakeWindowHours(birthdate);
  }

  /// Typical nap duration in hours, using the custom value if set,
  /// otherwise the age-based guideline.
  ({double minHours, double maxHours}) get effectiveNapDurationHours {
    if (napDurationMinMinutes != null && napDurationMaxMinutes != null) {
      return (
        minHours: napDurationMinMinutes! / 60.0,
        maxHours: napDurationMaxMinutes! / 60.0,
      );
    }
    return SleepKnowledgeBase.getNapDurationHours(birthdate);
  }

  /// Same as [effectiveWakeWindowHours] but tolerant of a null profile,
  /// so call sites don't need to null-check before falling back.
  static ({double minHours, double maxHours}) wakeWindowHoursFor(
    BabyProfile? profile,
  ) =>
      profile?.effectiveWakeWindowHours ??
      SleepKnowledgeBase.getWakeWindowHours(null);

  /// Same as [effectiveNapDurationHours] but tolerant of a null profile,
  /// so call sites don't need to null-check before falling back.
  static ({double minHours, double maxHours}) napDurationHoursFor(
    BabyProfile? profile,
  ) =>
      profile?.effectiveNapDurationHours ??
      SleepKnowledgeBase.getNapDurationHours(null);

  String get targetBedtimeString {
    if (targetBedtimeHour == null || targetBedtimeMinute == null) return '--:--';
    return '${targetBedtimeHour.toString().padLeft(2, '0')}:${targetBedtimeMinute.toString().padLeft(2, '0')}';
  }

  int get ageInWeeks {
    if (birthdate == null) return 0;
    return DateTime.now().difference(birthdate!).inDays ~/ 7;
  }

  String getAgeString({bool isPt = true}) {
    if (birthdate == null) {
      return isPt ? 'Idade desconhecida' : 'Unknown age';
    }
    final weeks = ageInWeeks;
    if (weeks < 4) {
      return isPt
          ? '$weeks semana${weeks == 1 ? '' : 's'}'
          : '$weeks week${weeks == 1 ? '' : 's'}';
    }
    final months = weeks ~/ 4;
    final remainWeeks = weeks % 4;
    if (months < 12) {
      if (remainWeeks == 0) {
        return isPt
            ? '$months mês${months == 1 ? '' : 'es'}'
            : '$months month${months == 1 ? '' : 's'}';
      }
      return isPt
          ? '$months mês${months == 1 ? '' : 'es'} e $remainWeeks semana${remainWeeks == 1 ? '' : 's'}'
          : '$months month${months == 1 ? '' : 's'} and $remainWeeks week${remainWeeks == 1 ? '' : 's'}';
    }
    final years = months ~/ 12;
    final remainMonths = months % 12;
    if (remainMonths == 0) {
      return isPt
          ? '$years ano${years == 1 ? '' : 's'}'
          : '$years year${years == 1 ? '' : 's'}';
    }
    return isPt
        ? '$years ano${years == 1 ? '' : 's'} e $remainMonths mês${remainMonths == 1 ? '' : 'es'}'
        : '$years year${years == 1 ? '' : 's'} and $remainMonths month${remainMonths == 1 ? '' : 's'}';
  }

  String getFeedingLabel({bool isPt = true}) {
    switch (feedingType) {
      case 'breast':
        return isPt ? 'Aleitamento exclusivo' : 'Exclusive breastfeeding';
      case 'formula':
        return isPt ? 'Fórmula' : 'Formula';
      case 'mixed':
        return isPt ? 'Misto (peito + fórmula)' : 'Mixed (breast + formula)';
      default:
        return feedingType;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'birthdate': birthdate?.toIso8601String(),
        'sex': sex,
        'feedingType': feedingType,
        'complementaryFoodStarted': complementaryFoodStarted,
        'nightRoutineMinutes': nightRoutineMinutes,
        'targetBedtimeHour': targetBedtimeHour,
        'targetBedtimeMinute': targetBedtimeMinute,
        'wakeWindowMinMinutes': wakeWindowMinMinutes,
        'wakeWindowMaxMinutes': wakeWindowMaxMinutes,
        'napDurationMinMinutes': napDurationMinMinutes,
        'napDurationMaxMinutes': napDurationMaxMinutes,
      };

  static DateTime? _parseFirestoreDate(dynamic value) {
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

  static int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory BabyProfile.fromFirestore(Map<String, dynamic> data) => BabyProfile(
        name: data['name'] as String?,
        birthdate: _parseFirestoreDate(data['birthdate']),
        sex: (data['sex'] as String?) ?? 'male',
        feedingType: (data['feedingType'] as String?) ?? 'breast',
        complementaryFoodStarted:
            (data['complementaryFoodStarted'] as bool?) ?? false,
        nightRoutineMinutes: _parseInt(data['nightRoutineMinutes'], 30),
        targetBedtimeHour: _parseNullableInt(data['targetBedtimeHour']),
        targetBedtimeMinute: _parseNullableInt(data['targetBedtimeMinute']),
        wakeWindowMinMinutes: _parseNullableInt(data['wakeWindowMinMinutes']),
        wakeWindowMaxMinutes: _parseNullableInt(data['wakeWindowMaxMinutes']),
        napDurationMinMinutes: _parseNullableInt(data['napDurationMinMinutes']),
        napDurationMaxMinutes: _parseNullableInt(data['napDurationMaxMinutes']),
      );
}
