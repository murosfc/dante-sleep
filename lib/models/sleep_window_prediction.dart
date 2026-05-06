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

  const SleepWindow({
    required this.isAwake,
    required this.startTime,
    this.endTime,
    this.rationale,
  });

  String displayText(bool isPt) {
    final emoji = isAwake ? '🟢' : '😴';
    final type = isAwake ? (isPt ? 'Acordado' : 'Awake') : (isPt ? 'Sono' : 'Sleep');
    final timeRange = endTime != null
        ? '$startTime → $endTime'
        : '$startTime → ${isPt ? 'Até acordar' : 'Until waking'}';
    final suffix = rationale != null && rationale!.isNotEmpty ? ' ($rationale)' : '';
    return '$emoji $type: $timeRange$suffix';
  }
}
