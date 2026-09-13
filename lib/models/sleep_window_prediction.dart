class SleepWindowPrediction {
  final String period; // 'morning', 'midday', 'afternoon', 'evening', 'night'
  final String periodName; // '🌅 Manhã', '🌞 Meio do dia', etc.
  final List<SleepWindow> windows;

  const SleepWindowPrediction({
    required this.period,
    required this.periodName,
    required this.windows,
  });
}

class SleepWindow {
  final bool isAwake;
  final String startTime;
  final String? endTime; // null for ongoing sleep
  final String? rationale;

  /// Optional display label (e.g. "Soneca 1", "Sono noturno"). When null the
  /// UI falls back to a generic awake/asleep label.
  final String? label;

  /// True for the final night-sleep block, which runs into the next day.
  final bool spansToNextDay;

  const SleepWindow({
    required this.isAwake,
    required this.startTime,
    this.endTime,
    this.rationale,
    this.label,
    this.spansToNextDay = false,
  });

  String displayText(bool isPt) {
    final emoji = isAwake ? '🟢' : '😴';
    final type = isAwake ? (isPt ? 'Acordado' : 'Awake') : (isPt ? 'Sono' : 'Sleep');
    final timeRange = endTime != null
        ? '$startTime → $endTime'
        : '$startTime → ${isPt ? 'Até acordar' : 'Until waking'}';
    return '$emoji $type: $timeRange';
  }
}
