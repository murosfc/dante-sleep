import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final strings = LocalizedStrings(context);
    final isDay = provider.isDay;
    final textColor = isDay ? const Color(0xFF12233F) : const Color(0xFFF2ECFF);
    final subtitleColor = isDay ? const Color(0xFF4B6287) : const Color(0xFFB8A7D5);

    final filtered = _applyPeriodFilter(provider.entries, _period)
      ..sort((a, b) {
        final aDate = a.slept ?? a.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.slept ?? b.wokeUp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    final nightSummary = _buildLastNightSummary(provider.entries);

    final sleepSpots = <FlSpot>[];
    final awakeSpots = <FlSpot>[];
    final bars = <BarChartGroupData>[];
    double maxY = 1;

    for (int i = 0; i < filtered.length; i++) {
      final sleepHours = _sleepHours(filtered[i]);
      final awakeHours = _awakeHours(filtered, i);
      sleepSpots.add(FlSpot(i.toDouble(), sleepHours));
      awakeSpots.add(FlSpot(i.toDouble(), awakeHours));
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: sleepHours,
              width: 12,
              borderRadius: BorderRadius.circular(6),
              color: isDay ? const Color(0xFF2A6CE8) : const Color(0xFF9A7CFF),
            ),
          ],
        ),
      );
      if (sleepHours > maxY) maxY = sleepHours;
      if (awakeHours > maxY) maxY = awakeHours;
    }
    maxY = (maxY + 1).clamp(2, 24);

    return Scaffold(
      appBar: AppBar(title: Text(strings.analyticsTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                title: Text(
                  strings.lastNightSummary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
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
            if (filtered.isEmpty)
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
                    _buildChartCard(
                      title: strings.sleepAwakeTrend,
                      child: SizedBox(
                        height: 260,
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
                                    '${value.toInt()}${strings.hoursUnit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
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
                                color: isDay
                                    ? const Color(0xFF2A6CE8)
                                    : const Color(0xFF9A7CFF),
                                dotData: const FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: awakeSpots,
                                isCurved: true,
                                barWidth: 3,
                                color: isDay
                                    ? const Color(0xFF35B6A8)
                                    : const Color(0xFF64D6CA),
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildChartCard(
                      title: strings.dailySleepDistribution,
                      child: SizedBox(
                        height: 260,
                        child: BarChart(
                          BarChartData(
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
                                    '${value.toInt()}${strings.hoursUnit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: bars,
                          ),
                        ),
                      ),
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

  Widget _buildSummaryMetric(
    String label,
    String value,
    Color textColor,
    Color subtitleColor,
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
          const SizedBox(height: 4),
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

  _NightSummary? _buildLastNightSummary(List<SleepEntry> entriesNewestFirst) {
    if (entriesNewestFirst.isEmpty) return null;

    int start = -1;
    for (int i = 0; i < entriesNewestFirst.length; i++) {
      if (!entriesNewestFirst[i].isDay) {
        start = i;
        break;
      }
    }
    if (start == -1) return null;

    final indices = <int>[];
    for (int i = start; i < entriesNewestFirst.length; i++) {
      if (!entriesNewestFirst[i].isDay) {
        indices.add(i);
      } else {
        break;
      }
    }
    if (indices.isEmpty) return null;

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
      if (idx - 1 >= 0 && indices.contains(idx - 1)) {
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

  String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
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
