/// Pure, AI-free calculator for the manual sleep plan.
///
/// When AI suggestions are disabled the app builds the day itself by chaining,
/// starting from the morning wake-up:
///
///   morningWake + WW[0] → nap 0 (lasts ND[0]) + WW[1] → nap 1 (ND[1]) + … +
///   WW[N] → night routine start
///
/// where `WW` are the wake windows (N+1 of them for N naps) and `ND` the nap
/// durations (N of them). The end of the last wake window is the moment the
/// night routine begins (per product decision: the chained total is the
/// ritual start, not sleep onset).
///
/// The plan is re-anchored on every real event the user logs: pass the last
/// event's time, whether the baby is currently asleep, and how many naps have
/// already finished today, and the remaining naps are recomputed forward from
/// that real timestamp.
library;

class ManualNap {
  /// 0-based index within the day (nap 0 is the first nap after morning wake).
  final int index;
  final DateTime start;
  final DateTime end;

  const ManualNap({
    required this.index,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}

class ManualDaySchedule {
  /// Every nap of the day, including any nap already in progress at anchor time.
  final List<ManualNap> naps;

  /// When the night routine should begin (end of the last wake window).
  final DateTime nightRoutineStart;

  const ManualDaySchedule({
    required this.naps,
    required this.nightRoutineStart,
  });

  /// Naps whose start is still in the future relative to [reference].
  List<ManualNap> upcomingNaps(DateTime reference) =>
      naps.where((n) => n.start.isAfter(reference)).toList(growable: false);

  /// The next nap that has not started yet, or null if the day's naps are done.
  ManualNap? nextNap(DateTime reference) {
    for (final nap in naps) {
      if (nap.start.isAfter(reference)) return nap;
    }
    return null;
  }
}

class ManualSleepPlan {
  ManualSleepPlan._();

  /// Builds the remaining schedule for the day.
  ///
  /// - [anchorTime]: timestamp of the last logged event (morning wake-up, a
  ///   nap start, or a nap wake-up).
  /// - [anchorIsAsleep]: true when [anchorTime] is a *sleep* event and the baby
  ///   is still asleep (the nap in progress is nap number [completedNaps]).
  /// - [completedNaps]: how many naps have fully finished today (baby woke up
  ///   from them). 0 means [anchorTime] is the morning wake-up.
  /// - [wakeWindowsMinutes]: exactly `napsPerDay + 1` entries.
  /// - [napDurationsMinutes]: exactly `napsPerDay` entries.
  static ManualDaySchedule compute({
    required DateTime anchorTime,
    required bool anchorIsAsleep,
    required int completedNaps,
    required List<int> wakeWindowsMinutes,
    required List<int> napDurationsMinutes,
  }) {
    final napsPerDay = napDurationsMinutes.length;
    final naps = <ManualNap>[];

    var cursor = anchorTime;
    var index = completedNaps.clamp(0, napsPerDay);

    // A nap already in progress at anchor time: close it out first.
    if (anchorIsAsleep && index < napsPerDay) {
      final end = anchorTime.add(Duration(minutes: napDurationsMinutes[index]));
      naps.add(ManualNap(index: index, start: anchorTime, end: end));
      cursor = end;
      index++;
    }

    // Remaining naps: wake window, then nap, repeated.
    while (index < napsPerDay) {
      final start =
          cursor.add(Duration(minutes: _gap(wakeWindowsMinutes, index)));
      final end = start.add(Duration(minutes: napDurationsMinutes[index]));
      naps.add(ManualNap(index: index, start: start, end: end));
      cursor = end;
      index++;
    }

    // Final wake window leads into the night routine.
    final nightRoutineStart =
        cursor.add(Duration(minutes: _gap(wakeWindowsMinutes, napsPerDay)));

    return ManualDaySchedule(naps: naps, nightRoutineStart: nightRoutineStart);
  }

  static int _gap(List<int> wakeWindowsMinutes, int i) {
    if (wakeWindowsMinutes.isEmpty) return 150;
    return i < wakeWindowsMinutes.length
        ? wakeWindowsMinutes[i]
        : wakeWindowsMinutes.last;
  }
}
