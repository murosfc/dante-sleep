class AiSuggestion {
  final String? nextNapTime;
  final String? nextNapRationale;
  final String? bedtimeRoutineStart;
  final String? bedtimeRationale;
  final DateTime? generatedAt;
  final bool isLoading;
  final String? error;

  const AiSuggestion({
    this.nextNapTime,
    this.nextNapRationale,
    this.bedtimeRoutineStart,
    this.bedtimeRationale,
    this.generatedAt,
    this.isLoading = false,
    this.error,
  });

  const AiSuggestion.loading() : this(isLoading: true);

  bool get hasContent =>
      !isLoading &&
      error == null &&
      (nextNapTime != null || bedtimeRoutineStart != null);
}
