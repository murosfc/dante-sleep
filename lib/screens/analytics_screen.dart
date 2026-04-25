import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_strings.dart';
import '../models/entry.dart';
import '../providers/app_provider.dart';

enum AnalyticsPeriod { all, days7, days14, days30 }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.all;
  DateTime? _selectedNightStartDate;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final strings = LocalizedStrings(context);
    final isDay = provider.isVisualDay;
    final textColor = isDay ? const Color(0xFF12233F) : const Color(0xFFF2ECFF);
    final subtitleColor = isDay ? const Color(0xFF4B6287) : const Color(0xFFB8A7D5);

    final filtered = _applyPeriodFilter(provider.entries, _period)
      ..sort((a, b) {
        final aDate = a.slept ?? a.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.slept ?? b.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    final nightGroups = _buildNightGroups(provider.entries);
    final latestNightDate = nightGroups.isEmpty ? null : nightGroups.first.startDate;
    final effectiveNightDate = _resolveEffectiveNightDate(nightGroups, latestNightDate);
    final selectedNightGroup = effectiveNightDate == null
      ? null
      : _findNightGroupByDate(nightGroups, effectiveNightDate);
    final nightSummary = selectedNightGroup?.summary;

    final nightDailySummaries =
        _buildDailySummaries(filtered.where((entry) => !entry.isDay).toList());
    final dayDailySummaries =
        _buildDailySummaries(filtered.where((entry) => entry.isDay).toList());

    return Scaffold(
      appBar: AppBar(title: Text(strings.analyticsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (effectiveNightDate != null)
              Row(
                children: [
                  Text(
                    strings.lastNightSummary,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _pickNightDate(context, nightGroups),
                    icon: const Icon(Icons.calendar_today, size: 15),
                    label: Text(_formatNightDateLabel(effectiveNightDate, context)),
                  ),
                ],
              )
            else
              Text(
                strings.lastNightSummary,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            const SizedBox(height: 8),
            Card(
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Row(
                  children: [
                    Text(
                      strings.lastNightSummary,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    if (effectiveNightDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatNightDateLabel(effectiveNightDate, context),
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                iconColor: textColor,
                collapsedIconColor: textColor,
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  if (nightSummary == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        strings.noLastNightData,
                        style: TextStyle(color: subtitleColor),
                      ),
                    )
                  else
                    Column(
                      children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.totalSlept,
                                    _formatHours(nightSummary.totalSleepHours),
                                    textColor,
                                    subtitleColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.totalAwake,
                                    _formatHours(nightSummary.totalAwakeHours),
                                    textColor,
                                    subtitleColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.wakeUps,
                                    '${nightSummary.wakeCount} ${strings.timesUnit}',
                                    textColor,
                                  subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.averageSleep,
                                    _formatHours(nightSummary.avgSleepBlock),
                                    textColor,
                                    subtitleColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.averageAwake,
                                    _formatHours(nightSummary.avgAwakeBlock),
                                    textColor,
                                    subtitleColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildSummaryMetric(
                                    strings.maxSleep,
                                    _formatHours(nightSummary.maxSleepBlock),
                                    textColor,
                                    subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  strings.filterPeriod,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AnalyticsPeriod>(
                    initialValue: _period,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: isDay
                          ? const Color(0xFFF3F8FF)
                          : const Color(0xFF221834),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: AnalyticsPeriod.all,
                        child: Text(strings.periodAll),
                      ),
                      DropdownMenuItem(
                        value: AnalyticsPeriod.days7,
                        child: Text(strings.period7Days),
                      ),
                      DropdownMenuItem(
                        value: AnalyticsPeriod.days14,
                        child: Text(strings.period14Days),
                      ),
                      DropdownMenuItem(
                        value: AnalyticsPeriod.days30,
                        child: Text(strings.period30Days),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _period = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (nightDailySummaries.isEmpty && dayDailySummaries.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    strings.noDataForPeriod,
                    style: TextStyle(color: subtitleColor, fontSize: 16),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    _buildSleepAwakePeriodChart(
                      title: _t(context, 'Noturno • Sono x Acordado', 'Night • Sleep vs Awake'),
                      data: nightDailySummaries,
                      subtitleColor: subtitleColor,
                      sleepColor: isDay
                          ? const Color(0xFF2A6CE8)
                          : const Color(0xFF9A7CFF),
                      awakeColor: isDay
                          ? const Color(0xFF35B6A8)
                          : const Color(0xFF64D6CA),
                      emptyText: _t(context, 'Sem dados noturnos no período', 'No night data for selected period'),
                      hoursUnit: strings.hoursUnit,
                      sleepLabel: strings.totalSlept,
                      awakeLabel: strings.totalAwake,
                    ),
                    const SizedBox(height: 12),
                    _buildSleepAwakePeriodChart(
                      title: _t(context, 'Diurno • Sono x Acordado', 'Day • Sleep vs Awake'),
                      data: dayDailySummaries,
                      subtitleColor: subtitleColor,
                      sleepColor: isDay
                          ? const Color(0xFF4A86F8)
                          : const Color(0xFFC3AEFF),
                      awakeColor: isDay
                          ? const Color(0xFF57C8B8)
                          : const Color(0xFF82E6DB),
                      emptyText: _t(context, 'Sem dados diurnos no período', 'No day data for selected period'),
                      hoursUnit: strings.hoursUnit,
                      sleepLabel: strings.totalSlept,
                      awakeLabel: strings.totalAwake,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSleepAwakePeriodChart({
    required String title,
    required List<_DailySummary> data,
    required Color subtitleColor,
    required Color sleepColor,
    required Color awakeColor,
    required String emptyText,
    required String hoursUnit,
    required String sleepLabel,
    required String awakeLabel,
  }) {
    if (data.isEmpty) {
      return _buildChartCard(
        title: title,
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              emptyText,
              style: TextStyle(color: subtitleColor),
            ),
          ),
        ),
      );
    }

    final sleepSpots = <FlSpot>[];
    final awakeSpots = <FlSpot>[];
    double maxY = 1;

    for (int i = 0; i < data.length; i++) {
      sleepSpots.add(FlSpot(i.toDouble(), data[i].sleepHours));
      awakeSpots.add(FlSpot(i.toDouble(), data[i].awakeHours));
      if (data[i].sleepHours > maxY) maxY = data[i].sleepHours;
      if (data[i].awakeHours > maxY) maxY = data[i].awakeHours;
    }

    maxY = (maxY + 1).clamp(2, 24);
    final bottomInterval = data.length > 10 ? 2 : 1;

    return _buildChartCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartLegend(
            subtitleColor: subtitleColor,
            sleepColor: sleepColor,
            awakeColor: awakeColor,
            sleepLabel: sleepLabel,
            awakeLabel: awakeLabel,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: subtitleColor.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}$hoursUnit',
                        style: TextStyle(
                          fontSize: 10,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: bottomInterval.toDouble(),
                      reservedSize: 30,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        if (idx % bottomInterval != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _shortDate(data[idx].date),
                            style: TextStyle(fontSize: 10, color: subtitleColor),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: sleepSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: sleepColor,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: awakeSpots,
                    isCurved: true,
                    barWidth: 3,
                    color: awakeColor,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend({
    required Color subtitleColor,
    required Color sleepColor,
    required Color awakeColor,
    required String sleepLabel,
    required String awakeLabel,
  }) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendItem(color: sleepColor, label: sleepLabel, subtitleColor: subtitleColor),
        _legendItem(color: awakeColor, label: awakeLabel, subtitleColor: subtitleColor),
      ],
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required Color subtitleColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  String _t(BuildContext context, String pt, String en) {
    return Localizations.localeOf(context).languageCode == 'pt' ? pt : en;
  }

  Widget _buildSummaryMetric(
    String label,
    String value,
    Color textColor,
    Color subtitleColor
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: subtitleColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
          ),
        ],
      ),
    );
  }

  List<SleepEntry> _applyPeriodFilter(List<SleepEntry> entries, AnalyticsPeriod period) {
    if (period == AnalyticsPeriod.all) {
      return List<SleepEntry>.from(entries);
    }

    final now = DateTime.now();
    final days = switch (period) {
      AnalyticsPeriod.days7 => 7,
      AnalyticsPeriod.days14 => 14,
      AnalyticsPeriod.days30 => 30,
      AnalyticsPeriod.all => 0,
    };
    final start = now.subtract(Duration(days: days));

    return entries.where((entry) {
      final anchor = entry.slept ?? entry.wokeUp;
      if (anchor == null) return false;
      return !anchor.isBefore(start);
    }).toList();
  }

  double _sleepHours(SleepEntry entry) {
    if (entry.slept == null || entry.wokeUp == null) return 0;
    final diff = entry.wokeUp!.difference(entry.slept!);
    if (diff.isNegative) return 0;
    return diff.inMinutes / 60;
  }

  double _awakeHours(List<SleepEntry> chronological, int index) {
    if (chronological[index].wokeUp == null || index + 1 >= chronological.length) {
      return 0;
    }
    final nextSlept = chronological[index + 1].slept;
    if (nextSlept == null) return 0;
    final diff = nextSlept.difference(chronological[index].wokeUp!);
    if (diff.isNegative) return 0;
    return diff.inMinutes / 60;
  }

  Future<void> _pickNightDate(
    BuildContext context,
    List<_NightGroup> nightGroups,
  ) async {
    if (nightGroups.isEmpty) return;

    final dates = nightGroups.map((g) => g.startDate).toList()
      ..sort((a, b) => a.compareTo(b));

    final initialDate = _resolveEffectiveNightDate(nightGroups, nightGroups.first.startDate) ?? nightGroups.first.startDate;
    final locale = Localizations.localeOf(context);
    final picked = await showDatePicker(
      context: context,
      locale: locale,
      initialDate: initialDate,
      firstDate: dates.first,
      lastDate: dates.last,
      selectableDayPredicate: (day) {
        return nightGroups.any((group) => _isSameDay(group.startDate, day));
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedNightStartDate = _asDateOnly(picked);
    });
  }

  List<_NightGroup> _buildNightGroups(List<SleepEntry> entriesNewestFirst) {
    if (entriesNewestFirst.isEmpty) return const [];

    final rawGroups = <_NightGroup>[];
    int i = 0;

    while (i < entriesNewestFirst.length) {
      if (entriesNewestFirst[i].isDay) {
        i++;
        continue;
      }

      final indices = <int>[];
      while (i < entriesNewestFirst.length && !entriesNewestFirst[i].isDay) {
        indices.add(i);
        i++;
      }

      final startDate = _extractNightStartDate(entriesNewestFirst, indices);
      final summary = _buildNightSummary(entriesNewestFirst, indices);
      if (startDate != null && summary != null) {
        rawGroups.add(_NightGroup(startDate: startDate, summary: summary));
      }
    }

    final byDate = <String, _NightGroup>{};
    for (final group in rawGroups) {
      final key = '${group.startDate.year}-${group.startDate.month}-${group.startDate.day}';
      byDate.putIfAbsent(key, () => group);
    }

    return byDate.values.toList();
  }

  DateTime? _extractNightStartDate(
    List<SleepEntry> entriesNewestFirst,
    List<int> indices,
  ) {
    DateTime? anchor;
    for (final idx in indices) {
      final entry = entriesNewestFirst[idx];
      final candidate = entry.slept ?? entry.wokeUp;
      if (candidate == null) continue;
      if (anchor == null || candidate.isBefore(anchor)) {
        anchor = candidate;
      }
    }
    if (anchor == null) return null;
    return _asDateOnly(anchor);
  }

  _NightSummary? _buildNightSummary(
    List<SleepEntry> entriesNewestFirst,
    List<int> indices,
  ) {
    if (indices.isEmpty) return null;

    final indexSet = indices.toSet();

    double totalSleep = 0;
    double totalAwake = 0;
    int wakeCount = 0;
    double maxSleepBlock = 0;
    int sleepBlockCount = 0;
    int awakeBlockCount = 0;

    for (final idx in indices) {
      final entry = entriesNewestFirst[idx];
      var sleepHrs = _sleepHours(entry);
      if (sleepHrs > 0) {
        totalSleep += sleepHrs;
        sleepBlockCount++;
        if (sleepHrs > maxSleepBlock) maxSleepBlock = sleepHrs;
      }

      if (entry.wokeUp != null) {
        wakeCount++;
      }
      if (idx - 1 >= 0 && indexSet.contains(idx - 1)) {
        final newer = entriesNewestFirst[idx - 1];
        if (newer.slept != null && entry.wokeUp != null) {
          final diff = newer.slept!.difference(entry.wokeUp!);
          if (!diff.isNegative) {
            totalAwake += diff.inMinutes / 60;
            awakeBlockCount++;
          }
        }
      }
    }

    double avgSleep = sleepBlockCount > 0 ? totalSleep / sleepBlockCount : 0;
    double avgAwake = awakeBlockCount > 0 ? totalAwake / awakeBlockCount : 0;

    return _NightSummary(
      totalSleepHours: totalSleep,
      totalAwakeHours: totalAwake,
      wakeCount: wakeCount,
      maxSleepBlock: maxSleepBlock,
      avgSleepBlock: avgSleep,
      avgAwakeBlock: avgAwake,
    );
  }

  DateTime? _resolveEffectiveNightDate(
    List<_NightGroup> nightGroups,
    DateTime? fallback,
  ) {
    if (_selectedNightStartDate == null) return fallback;

    final selected = _selectedNightStartDate!;
    final exists = nightGroups.any((group) => _isSameDay(group.startDate, selected));
    return exists ? selected : fallback;
  }

  _NightGroup? _findNightGroupByDate(List<_NightGroup> nightGroups, DateTime date) {
    for (final group in nightGroups) {
      if (_isSameDay(group.startDate, date)) {
        return group;
      }
    }
    return null;
  }

  DateTime _asDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatNightDateLabel(DateTime date, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode == 'pt' ? 'pt_BR' : 'en';
    return DateFormat('dd-MMM', locale).format(date);
  }

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  List<_DailySummary> _buildDailySummaries(List<SleepEntry> filtered) {
    if (filtered.isEmpty) return const [];

    final chronological = List<SleepEntry>.from(filtered)
      ..sort((a, b) {
        final aDate = a.slept ?? a.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.slept ?? b.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

    final byDay = <String, _DailySummary>{};

    for (int i = 0; i < chronological.length; i++) {
      final entry = chronological[i];
      final anchor = entry.slept ?? entry.wokeUp;
      if (anchor == null) continue;
      final day = _asDateOnly(anchor);
      final key = '${day.year}-${day.month}-${day.day}';

      final current = byDay[key] ?? _DailySummary(date: day, sleepHours: 0, awakeHours: 0, wakeUps: 0);
      final sleep = _sleepHours(entry);
      final awake = _awakeHours(chronological, i);

      byDay[key] = _DailySummary(
        date: day,
        sleepHours: current.sleepHours + sleep,
        awakeHours: current.awakeHours + awake,
        wakeUps: current.wakeUps + (entry.wokeUp != null ? 1 : 0),
      );
    }

    final result = byDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  String _shortDate(DateTime date) {
    return DateFormat('dd/MM').format(date);
  }
}

class _NightSummary {
  final double totalSleepHours;
  final double totalAwakeHours;
  final int wakeCount;
  final double maxSleepBlock;
  final double avgSleepBlock;
  final double avgAwakeBlock;

  _NightSummary({
    required this.totalSleepHours,
    required this.totalAwakeHours,
    required this.wakeCount,
    required this.maxSleepBlock,
    required this.avgSleepBlock,
    required this.avgAwakeBlock,
  });
}

class _NightGroup {
  final DateTime startDate;
  final _NightSummary summary;

  _NightGroup({required this.startDate, required this.summary});
}

class _DailySummary {
  final DateTime date;
  final double sleepHours;
  final double awakeHours;
  final int wakeUps;

  const _DailySummary({
    required this.date,
    required this.sleepHours,
    required this.awakeHours,
    required this.wakeUps,
  });
}
