import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/localized_strings.dart';
import '../models/entry.dart';
import '../providers/app_provider.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final strings = LocalizedStrings(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.appTitle,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (provider.selectedIndex != null)
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _showDeleteConfirmationDialog(context, provider),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export') {
                final filename = await provider.exportCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.getCsvExportedMessage(filename)),
                    ),
                  );
                }
              } else if (value == 'language') {
                _showLanguageDialog(context, provider, strings);
              } else if (value == 'time_format') {
                _showTimeFormatDialog(context, provider, strings);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'export', child: Text(strings.exportCsv)),
              PopupMenuItem(value: 'language', child: Text(strings.language)),
              PopupMenuItem(
                value: 'time_format',
                child: Text(strings.timeFormat),
              ),
            ],
          ),
        ],
        backgroundColor: provider.isDay ? Colors.blue : Colors.purple,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: provider.isDay
                ? Colors.blue.shade100
                : Colors.purple.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    provider.isDay ? Icons.wb_sunny : Icons.nightlight_round,
                  ),
                  onPressed: provider.togglePeriod,
                  iconSize: 40,
                ),
                ElevatedButton(
                  onPressed: provider.toggleButton,
                  child: Text(
                    provider.isDormiu
                        ? strings.sleptButton
                        : strings.wokeUpButton,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.child_care),
                  onPressed: provider.toggleBottle,
                  iconSize: 40,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.dormiu,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text(
                    strings.acordou,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text(
                    strings.diaNoite,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text(
                    strings.mamou,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Text(
                    strings.status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: provider.entries.length,
              itemBuilder: (context, index) {
                SleepEntry entry = provider.entries[index];
                bool isSelected = provider.selectedIndex == index;
                return GestureDetector(
                  onTap: () => provider.selectRow(index),
                  child: Container(
                    color: isSelected ? Colors.grey.shade200 : null,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onLongPress: () =>
                                _editDateTime(context, provider, index, false),
                            child: Text(
                              entry.getFormattedSlept(
                                provider.locale,
                                provider.is24Hour,
                              ),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onLongPress: () =>
                                _editDateTime(context, provider, index, true),
                            child: Text(
                              entry.getFormattedWokeUp(
                                provider.locale,
                                provider.is24Hour,
                              ),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: Icon(
                              entry.isDay
                                  ? Icons.wb_sunny
                                  : Icons.nightlight_round,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                            onPressed: isSelected
                                ? provider.updateSelectedPeriod
                                : null,
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: Icon(
                              entry.bottle
                                  ? Icons.child_care
                                  : Icons.not_interested,
                              color: isSelected
                                  ? Colors.black
                                  : (entry.bottle ? Colors.white : Colors.grey),
                            ),
                            onPressed: isSelected
                                ? provider.updateSelectedBottle
                                : null,
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onLongPress: () => _showTimesInfo(
                              context,
                              entry,
                              provider.entries,
                              index,
                              strings,
                            ),
                            child: Icon(
                              Icons.info,
                              size: 27,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
        title: Text(strings.selectLanguage),
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
        title: Text(strings.timeFormatTitle),
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
    if (current == null) return;
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
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

  void _showDeleteConfirmationDialog(
    BuildContext context,
    AppProvider provider,
  ) {
    final strings = LocalizedStrings(context);
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
              if (provider.selectedIndex != null) {
                provider.deleteEntry(provider.selectedIndex!);
              }
              Navigator.pop(context);
            },
            child: Text(
              strings.deleteButton,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimesInfo(
    BuildContext context,
    SleepEntry entry,
    List<SleepEntry> allEntries,
    int index,
    LocalizedStrings strings,
  ) {
    int entryIndex = allEntries.indexOf(entry);
    String sleepTime = entry.getSleepTime(allEntries, entryIndex);
    String awakeTime = entry.getAwakeTime(allEntries, entryIndex);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.timeInformation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${strings.tempoDoricido}: $sleepTime'),
            Text('${strings.tempoAcordado}: $awakeTime'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.ok),
          ),
        ],
      ),
    );
  }
}
