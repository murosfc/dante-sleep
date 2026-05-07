class AiSuggestion {
  final String? nextNapTime;
  final String? nextNapRationale;
  final String? bedtimeRoutineStart;
  final String? bedtimeRationale;
  final String? nightWakeTime;
  final String? nightWakeRationale;
  final DateTime? generatedAt;
  final bool isLoading;
  final String? error;

  const AiSuggestion({
    this.nextNapTime,
    this.nextNapRationale,
    this.bedtimeRoutineStart,
    this.bedtimeRationale,
    this.nightWakeTime,
    this.nightWakeRationale,
    this.generatedAt,
    this.isLoading = false,
    this.error,
  });

  const AiSuggestion.loading() : this(isLoading: true);

  bool get hasContent =>
      !isLoading &&
      error == null &&
      (nextNapTime != null ||
          bedtimeRoutineStart != null ||
          nightWakeTime != null);

  AiSuggestion copyWith({
    String? nextNapTime,
    String? nextNapRationale,
    String? bedtimeRoutineStart,
    String? bedtimeRationale,
    String? nightWakeTime,
    String? nightWakeRationale,
    DateTime? generatedAt,
    bool? isLoading,
    String? error,
  }) {
    return AiSuggestion(
      nextNapTime: nextNapTime ?? this.nextNapTime,
      nextNapRationale: nextNapRationale ?? this.nextNapRationale,
      bedtimeRoutineStart: bedtimeRoutineStart ?? this.bedtimeRoutineStart,
      bedtimeRationale: bedtimeRationale ?? this.bedtimeRationale,
      nightWakeTime: nightWakeTime ?? this.nightWakeTime,
      nightWakeRationale: nightWakeRationale ?? this.nightWakeRationale,
      generatedAt: generatedAt ?? this.generatedAt,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
