class BabyProfile {
  String? name;
  DateTime? birthdate;
  String sex; // 'male' | 'female'
  String feedingType; // 'breast' | 'formula' | 'mixed'
  bool complementaryFoodStarted;
  int nightRoutineMinutes;
  int? targetBedtimeHour;
  int? targetBedtimeMinute;
  String? geminiApiKey;

  BabyProfile({
    this.name,
    this.birthdate,
    this.sex = 'male',
    this.feedingType = 'breast',
    this.complementaryFoodStarted = false,
    this.nightRoutineMinutes = 30,
    this.targetBedtimeHour,
    this.targetBedtimeMinute,
    this.geminiApiKey,
  });

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
        'geminiApiKey': geminiApiKey,
      };

  factory BabyProfile.fromFirestore(Map<String, dynamic> data) => BabyProfile(
        name: data['name'] as String?,
        birthdate: data['birthdate'] != null
            ? DateTime.tryParse(data['birthdate'] as String)
            : null,
        sex: (data['sex'] as String?) ?? 'male',
        feedingType: (data['feedingType'] as String?) ?? 'breast',
        complementaryFoodStarted:
            (data['complementaryFoodStarted'] as bool?) ?? false,
        nightRoutineMinutes: (data['nightRoutineMinutes'] as int?) ?? 30,
        targetBedtimeHour: data['targetBedtimeHour'] as int?,
        targetBedtimeMinute: data['targetBedtimeMinute'] as int?,
        geminiApiKey: data['geminiApiKey'] as String?,
      );
}
