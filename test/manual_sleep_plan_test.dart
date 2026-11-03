import 'package:dante_sleep/knowledge/manual_sleep_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wake windows 2:30, 3:00, 3:00 · naps 1:30, 1:30.
  const ww = [150, 180, 180];
  const nd = [90, 90];

  test('morning wake 06:30 → first nap 09:00, wakes 10:30', () {
    final s = ManualSleepPlan.compute(
      anchorTime: DateTime(2026, 11, 2, 6, 30),
      anchorIsAsleep: false,
      completedNaps: 0,
      wakeWindowsMinutes: ww,
      napDurationsMinutes: nd,
    );
    expect(s.naps.first.start, DateTime(2026, 11, 2, 9, 0));
    expect(s.naps.first.end, DateTime(2026, 11, 2, 10, 30));
  });

  test('woke from nap 1 at 10:30 → next nap 13:30', () {
    final s = ManualSleepPlan.compute(
      anchorTime: DateTime(2026, 11, 2, 10, 30),
      anchorIsAsleep: false,
      completedNaps: 1,
      wakeWindowsMinutes: ww,
      napDurationsMinutes: nd,
    );
    expect(s.naps.first.index, 1);
    expect(s.naps.first.start, DateTime(2026, 11, 2, 13, 30));
  });

  test('napping since 09:10 → should wake 10:40', () {
    final s = ManualSleepPlan.compute(
      anchorTime: DateTime(2026, 11, 2, 9, 10),
      anchorIsAsleep: true,
      completedNaps: 0,
      wakeWindowsMinutes: ww,
      napDurationsMinutes: nd,
    );
    expect(s.naps.first.end, DateTime(2026, 11, 2, 10, 40));
  });
}
