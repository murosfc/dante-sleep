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

  // ─── Manual sleep plan (used when [useAiSuggestions] is false) ────────────
  // When AI suggestions are disabled the app schedules naps/bedtime itself by
  // chaining, from the morning wake-up: wake window → nap → wake window → …
  // → last wake window, whose end is the start of the night routine.

  /// Whether AI suggestions drive nap/bedtime hints and notifications.
  /// Defaults to true so existing users are unaffected.
  bool useAiSuggestions;

  /// How many naps the manual plan schedules per day.
  int manualNapsPerDay;

  /// When true, a single wake-window value is reused for every gap of the day
  /// ([manualWakeWindowsMinutes] holds one entry). When false it holds
  /// [manualNapsPerDay] + 1 entries (one per gap, including morning→nap 1 and
  /// last nap→night routine).
  bool manualSameWakeWindow;

  /// Same idea as [manualSameWakeWindow] but for nap durations: one shared
  /// value, or [manualNapsPerDay] explicit entries.
  bool manualSameNapDuration;

  /// Wake-window durations in minutes (see [manualSameWakeWindow]).
  List<int> manualWakeWindowsMinutes;

  /// Nap durations in minutes (see [manualSameNapDuration]).
  List<int> manualNapDurationsMinutes;

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
    this.useAiSuggestions = true,
    this.manualNapsPerDay = 3,
    this.manualSameWakeWindow = true,
    this.manualSameNapDuration = true,
    List<int>? manualWakeWindowsMinutes,
    List<int>? manualNapDurationsMinutes,
  })  : manualWakeWindowsMinutes = manualWakeWindowsMinutes ?? const [150],
        manualNapDurationsMinutes = manualNapDurationsMinutes ?? const [90];

  /// Wake-window durations expanded to exactly [manualNapsPerDay] + 1 entries,
  /// so callers can index gap `i` (0 = morning→nap 1, last = nap N→routine)
  /// without worrying about the "same value" shorthand.
  List<int> get resolvedManualWakeWindowsMinutes =>
      _resolveManualList(manualWakeWindowsMinutes, manualNapsPerDay + 1, 150);

  /// Nap durations expanded to exactly [manualNapsPerDay] entries.
  List<int> get resolvedManualNapDurationsMinutes =>
      _resolveManualList(manualNapDurationsMinutes, manualNapsPerDay, 90);

  static List<int> _resolveManualList(
    List<int> source,
    int length,
    int fallback,
  ) {
    if (length <= 0) return const [];
    final base = source.isEmpty ? [fallback] : source;
    return List<int>.generate(
      length,
      (i) => i < base.length ? base[i] : base.last,
    );
  }

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
        'useAiSuggestions': useAiSuggestions,
        'manualNapsPerDay': manualNapsPerDay,
        'manualSameWakeWindow': manualSameWakeWindow,
        'manualSameNapDuration': manualSameNapDuration,
        'manualWakeWindowsMinutes': manualWakeWindowsMinutes,
        'manualNapDurationsMinutes': manualNapDurationsMinutes,
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

  static List<int>? _parseIntList(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    final parsed = <int>[];
    for (final item in value) {
      final n = _parseNullableInt(item);
      if (n != null) parsed.add(n);
    }
    return parsed.isEmpty ? null : parsed;
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
        useAiSuggestions: (data['useAiSuggestions'] as bool?) ?? true,
        manualNapsPerDay: _parseInt(data['manualNapsPerDay'], 3),
        manualSameWakeWindow: (data['manualSameWakeWindow'] as bool?) ?? true,
        manualSameNapDuration: (data['manualSameNapDuration'] as bool?) ?? true,
        manualWakeWindowsMinutes:
            _parseIntList(data['manualWakeWindowsMinutes']),
        manualNapDurationsMinutes:
            _parseIntList(data['manualNapDurationsMinutes']),
      );
}
