import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_strings.dart';
import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../widgets/settings_bottom_sheet.dart';
import 'analytics_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final provider = Provider.of<AppProvider>(context);
        final strings = LocalizedStrings(context);
        final isVisualDay = provider.isVisualDay;
        final isDayPeriod = provider.isDay;
        final textColor = isVisualDay ? const Color(0xFF12233F) : const Color(0xFFF2ECFF);
        final subtitleColor = isVisualDay
            ? const Color(0xFF4B6287)
            : const Color(0xFFB8A7D5);

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.appTitle),
            actions: [
              // Bell icon with badge
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      provider.markAiSuggestionsRead();
                      _showAiSuggestionsDialog(context, provider, strings, isVisualDay, textColor, subtitleColor);
                    },
                  ),
                  if (provider.hasPendingAiNotifications)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${provider.aiUnreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SettingsBottomSheet(),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: isVisualDay
                        ? const [Color(0xFFDBE8FF), Color(0xFFC8DCFF)]
                        : const [Color(0xFF1D1130), Color(0xFF130B20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isVisualDay
                          ? const Color(0x33246AE6)
                          : const Color(0x55100518),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: provider.togglePeriod,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isVisualDay
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF2A1A42),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          isDayPeriod ? Icons.wb_sunny : Icons.nightlight_round,
                          size: 28,
                          color: isDayPeriod
                              ? const Color(0xFF2A6CE8)
                              : const Color(0xFFEADFFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.toggleButton,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: isVisualDay
                              ? const Color(0xFF2A6CE8)
                              : const Color(0xFF4A2A72),
                          foregroundColor: const Color(0xFFFFFFFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          provider.isDormiu
                              ? strings.sleptButton
                              : strings.wokeUpButton,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AnalyticsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isVisualDay
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF2A1A42),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.bar_chart,
                          size: 28,
                          color: isVisualDay
                              ? const Color(0xFF2A6CE8)
                              : const Color(0xFFEADFFF),
                        ),
                      ),
                    ),
                    // Table/Card view toggle temporarily disabled.
                    // const SizedBox(width: 10),
                    // Tooltip(
                    //   message: provider.isTableView
                    //       ? strings.cardView
                    //       : strings.tableView,
                    //   child: InkWell(
                    //     borderRadius: BorderRadius.circular(14),
                    //     onTap: provider.toggleViewMode,
                    //     child: Container(
                    //       padding: const EdgeInsets.all(10),
                    //       decoration: BoxDecoration(
                    //         color: isDay
                    //             ? const Color(0xFFFFFFFF)
                    //             : const Color(0xFF2A1A42),
                    //         borderRadius: BorderRadius.circular(14),
                    //       ),
                    //       child: Icon(
                    //         provider.isTableView
                    //             ? Icons.view_agenda_outlined
                    //             : Icons.table_rows_outlined,
                    //         size: 24,
                    //         color: isDay
                    //             ? const Color(0xFF2A6CE8)
                    //             : const Color(0xFFEADFFF),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              Expanded(
                // Table view branch temporarily disabled. Keep card view only.
                // child: provider.isTableView
                //     ? _buildEntriesTable(
                //         context,
                //         provider,
                //         strings,
                //         isDay,
                //         textColor,
                //         subtitleColor,
                //       )
                //     : ListView.builder(
                child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        itemCount: provider.entries.length,
                        itemBuilder: (context, index) {
                          final entry = provider.entries[index];
                          final sleepTime = entry.getSleepTime(
                            provider.entries,
                            index,
                          );
                          final awakeTime = entry.getAwakeTime(
                            provider.entries,
                            index,
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  colors: isDay
                                      ? const [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFF6FAFF),
                                        ]
                                      : const [
                                          Color(0xFF211531),
                                          Color(0xFF170F24),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onLongPress: () => _editDateTime(
                                              context,
                                              provider,
                                              index,
                                              false,
                                            ),
                                            child: _buildTimeBlock(
                                              strings.dormiu,
                                              entry.getFormattedSlept(
                                                provider.locale,
                                                provider.is24Hour,
                                              ),
                                              textColor,
                                              subtitleColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onLongPress: () => _editDateTime(
                                              context,
                                              provider,
                                              index,
                                              true,
                                            ),
                                            child: _buildTimeBlock(
                                              strings.acordou,
                                              entry.getFormattedWokeUp(
                                                provider.locale,
                                                provider.is24Hour,
                                              ),
                                              textColor,
                                              subtitleColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () =>
                                              provider.toggleEntryExpanded(index),
                                          icon: Icon(
                                            entry.isExpanded
                                                ? Icons.expand_more
                                                : Icons.chevron_right,
                                            color: textColor,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    if (entry.isExpanded) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                          ActionChip(
                                            backgroundColor: isDay
                                                ? const Color(0xFFDDEBFF)
                                                : const Color(0xFF2A1A42),
                                            avatar: Icon(
                                              entry.isDay
                                                  ? Icons.wb_sunny
                                                  : Icons.nightlight_round,
                                              size: 18,
                                              color: textColor,
                                            ),
                                            label: Text(
                                              entry.isDay
                                                  ? strings.dayLabel
                                                  : strings.nightLabel,
                                              style: TextStyle(color: textColor),
                                            ),
                                            onPressed: () =>
                                                provider.updateEntryPeriod(index),
                                          ),
                                          GestureDetector(
                                            onLongPress: () => _editBottleTime(context, provider, index),
                                            child: ActionChip(
                                              backgroundColor: isDay
                                                  ? const Color(0xFFDDEBFF)
                                                  : const Color(0xFF2A1A42),
                                              avatar: SvgPicture.asset(
                                                'assets/icons/bottle.svg',
                                                width: 18,
                                                height: 18,
                                                colorFilter: isDay ? const ColorFilter.mode(Colors.black, BlendMode.srcIn) : null,
                                              ),
                                              label: Text(
                                                entry.bottle
                                                    ? (entry.bottleTime != null ? '${strings.mamou} ${entry.getFormattedBottleTime(provider.locale, provider.is24Hour)}' : strings.mamou)
                                                    : strings.didNotFeed,
                                                style: TextStyle(color: textColor),
                                              ),
                                              onPressed: () => provider
                                                  .updateSelectedBottle(index),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, color: textColor),
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deleteEntryConfirm(context, provider, strings, index);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.delete_outline, size: 20),
                                              const SizedBox(width: 8),
                                              Text(strings.deleteButton),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _buildMetricBlock(
                                          strings.tempoDoricido,
                                          sleepTime,
                                          isDay,
                                          textColor,
                                          subtitleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildMetricBlock(
                                          strings.tempoAcordado,
                                          awakeTime,
                                          isDay,
                                          textColor,
                                          subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    AppProvider provider,
    LocalizedStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.selectLanguage,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strings.english),
              onTap: () {
                provider.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(strings.portuguese),
              onTap: () {
                provider.setLanguage('pt');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeFormatDialog(
    BuildContext context,
    AppProvider provider,
    LocalizedStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.timeFormatTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(strings.hourFormat24),
              onTap: () {
                provider.set24Hour(true);
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(strings.hourFormat12),
              onTap: () {
                provider.set24Hour(false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editDateTime(
    BuildContext context,
    AppProvider provider,
    int index,
    bool isWokeUp,
  ) async {
    DateTime? current = isWokeUp
        ? provider.entries[index].wokeUp
        : provider.entries[index].slept;
    if (current == null) {
      current = provider.entries[index].slept ?? provider.entries[index].wokeUp ?? DateTime.now();
    }
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (!context.mounted) return;
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: provider.is24Hour,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
      if (!context.mounted) return;
      if (pickedTime != null) {
        DateTime newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        if (isWokeUp) {
          provider.editWokeUp(index, newDateTime);
        } else {
          provider.editSlept(index, newDateTime);
        }
      }
    }
  }

  void _editBottleTime(BuildContext context, AppProvider provider, int index) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: provider.entries[index].bottleTime != null
          ? TimeOfDay.fromDateTime(provider.entries[index].bottleTime!)
          : TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: provider.is24Hour),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime != null && context.mounted) {
      final baseDate = provider.entries[index].slept ?? provider.entries[index].wokeUp ?? DateTime.now();
      final newTime = DateTime(baseDate.year, baseDate.month, baseDate.day, pickedTime.hour, pickedTime.minute);
      provider.editBottleTime(index, newTime);
    }
  }

  void _deleteEntryConfirm(BuildContext context, AppProvider provider, LocalizedStrings strings, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteEntry),
        content: Text(strings.deleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              provider.deleteEntry(index);
              Navigator.pop(context);
            },
            child: Text(strings.deleteButton),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(
    String title,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: subtitleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBlock(
    String title,
    String value,
    bool isDay,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDay ? const Color(0xFFECF4FF) : const Color(0xFF2A1B3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildEntriesTable(
    BuildContext context,
    AppProvider provider,
    LocalizedStrings strings,
    bool isDay,
    Color textColor,
    Color subtitleColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 32),
        child: Card(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: isDay ? const Color(0xFFDCEAFF) : const Color(0xFF2B1D40),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    _buildTableHeaderCell(strings.dormiu, flex: 2, textColor: textColor),
                    _buildTableHeaderCell(strings.acordou, flex: 2, textColor: textColor),
                    _buildTableHeaderCell(strings.diaNoite, textColor: textColor),
                    _buildTableHeaderCell(strings.mamou, textColor: textColor),
                    _buildTableHeaderCell(
                      strings.tempoDoricido,
                      flex: 2,
                      textColor: textColor,
                    ),
                    _buildTableHeaderCell(
                      strings.tempoAcordado,
                      flex: 2,
                      textColor: textColor,
                    ),
                  ],
                ),
              ),
              for (int index = 0; index < provider.entries.length; index++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  color: index.isEven
                      ? (isDay ? const Color(0xFFF9FBFF) : const Color(0xFF1E152B))
                      : Colors.transparent,
                  child: Row(
                    children: [
                      _buildTableCell(
                        provider.entries[index].getFormattedSlept(
                          provider.locale,
                          provider.is24Hour,
                        ),
                        flex: 2,
                        textColor: textColor,
                        onLongPress: () =>
                            _editDateTime(context, provider, index, false),
                      ),
                      _buildTableCell(
                        provider.entries[index].getFormattedWokeUp(
                          provider.locale,
                          provider.is24Hour,
                        ),
                        flex: 2,
                        textColor: textColor,
                        onLongPress: () =>
                            _editDateTime(context, provider, index, true),
                      ),
                      Expanded(
                        child: Center(
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isDay
                                ? const Color(0xFFDDEBFF)
                                : const Color(0xFF2A1A42),
                            avatar: Icon(
                              provider.entries[index].isDay
                                  ? Icons.wb_sunny
                                  : Icons.nightlight_round,
                              size: 16,
                              color: textColor,
                            ),
                            label: Text(
                              provider.entries[index].isDay
                                  ? strings.dayLabel
                                  : strings.nightLabel,
                              style: TextStyle(color: textColor, fontSize: 12),
                            ),
                            onPressed: () => provider.updateEntryPeriod(index),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onLongPress: () => _editBottleTime(context, provider, index),
                            child: ActionChip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDay
                                  ? const Color(0xFFDDEBFF)
                                  : const Color(0xFF2A1A42),
                              avatar: SvgPicture.asset(
                                'assets/icons/bottle.svg',
                                width: 16,
                                height: 16,
                                colorFilter: isDay ? const ColorFilter.mode(Colors.black, BlendMode.srcIn) : null,
                              ),
                              label: Text(
                                provider.entries[index].bottle
                                    ? (provider.entries[index].bottleTime != null ? '${strings.mamou} ${provider.entries[index].getFormattedBottleTime(provider.locale, provider.is24Hour)}' : strings.mamou)
                                    : strings.didNotFeed,
                                style: TextStyle(color: textColor, fontSize: 12),
                              ),
                              onPressed: () => provider.updateSelectedBottle(index),
                            ),
                          ),
                        ),
                      ),
                      _buildTableCell(
                        provider.entries[index].getSleepTime(
                          provider.entries,
                          index,
                        ),
                        flex: 2,
                        textColor: subtitleColor,
                      ),
                      _buildTableCell(
                        provider.entries[index].getAwakeTime(
                          provider.entries,
                          index,
                        ),
                        flex: 2,
                        textColor: subtitleColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTableHeaderCell(
    String text, {
    int flex = 1,
    required Color textColor,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTableCell(
    String text, {
    int flex = 1,
    required Color textColor,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Text(
          text.isEmpty ? '-' : text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  void _showAiSuggestionsDialog(
    BuildContext context,
    AppProvider provider,
    LocalizedStrings strings,
    bool isDay,
    Color textColor,
    Color subtitleColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AiSuggestionsBottomSheet(
        provider: provider,
        strings: strings,
        isDay: isDay,
        textColor: textColor,
        subtitleColor: subtitleColor,
      ),
    );
  }
}

/// Full bottom sheet with rationale details
class _AiSuggestionsBottomSheet extends StatelessWidget {
  final AppProvider provider;
  final LocalizedStrings strings;
  final bool isDay;
  final Color textColor;
  final Color subtitleColor;

  const _AiSuggestionsBottomSheet({
    required this.provider,
    required this.strings,
    required this.isDay,
    required this.textColor,
    required this.subtitleColor,
  });

  bool get _isPt => provider.locale.languageCode == 'pt';
  String _t(String pt, String en) => _isPt ? pt : en;

  @override
  Widget build(BuildContext context) {
    final ai = provider.aiSuggestion;
    final bgColor = isDay ? Colors.white : const Color(0xFF1D1130);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF9A7CFF), size: 20),
                const SizedBox(width: 8),
                Text(
                  _t('Sugestões IA', 'AI Suggestions'),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.refreshAiSuggestions();
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF9A7CFF)),
                  label: Text(
                    _t('Atualizar', 'Refresh'),
                    style: const TextStyle(color: Color(0xFF9A7CFF), fontSize: 13),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (ai == null || ai.isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF9A7CFF)),
                      const SizedBox(height: 12),
                      Text(
                        _t('Analisando dados de sono…', 'Analyzing sleep data…'),
                        style: TextStyle(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              )
            else if (ai.error != null)
              Text(
                _t('Não foi possível gerar sugestões.', 'Could not generate suggestions.'),
                style: const TextStyle(color: Color(0xFFE57373)),
              )
            else ...[
              if (ai.nextNapTime != null)
                _SuggestionTile(
                  icon: Icons.bedtime_outlined,
                  title: _t('Próxima soneca', 'Next nap'),
                  time: ai.nextNapTime!,
                  rationale: ai.nextNapRationale,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              if (ai.bedtimeRoutineStart != null) ...[
                if (ai.nextNapTime != null) const SizedBox(height: 12),
                _SuggestionTile(
                  icon: Icons.nights_stay_outlined,
                  title: _t('Iniciar rotina noturna', 'Start night routine'),
                  time: ai.bedtimeRoutineStart!,
                  rationale: ai.bedtimeRationale,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ],
              if (ai.generatedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  _t(
                    'Gerado às ${_fmtTime(ai.generatedAt!)}',
                    'Generated at ${_fmtTime(ai.generatedAt!)}',
                  ),
                  style: TextStyle(color: subtitleColor, fontSize: 11),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String? rationale;
  final Color textColor;
  final Color subtitleColor;

  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.time,
    this.rationale,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A1B3E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1B3E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF9A7CFF), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFFEADFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rationale != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    rationale!,
                    style: TextStyle(color: subtitleColor, fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
