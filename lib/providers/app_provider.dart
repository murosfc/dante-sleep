import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';

class AppProvider with ChangeNotifier {
  List<SleepEntry> entries = [];

  bool get isDormiu {
    if (entries.isEmpty) return true;
    final latest = entries[0];
    if (latest.slept != null && latest.wokeUp == null) {
      return false;
    }
    return true;
  }
  bool isDay = true;
  bool is24Hour = true;
  bool isTableView = false;
  Locale locale = const Locale('en');
  int? selectedIndex;

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? entriesJson = prefs.getString('entries');
    if (entriesJson != null) {
      List<dynamic> list = jsonDecode(entriesJson);
      entries = list.map((e) => SleepEntry.fromJson(e)).toList();
    }
    is24Hour = prefs.getBool('is24Hour') ?? true;
    // Temporarily force card view on app startup.
    isTableView = false;
    String lang = prefs.getString('language') ?? 'en';
    locale = Locale(lang);
    DateTime now = DateTime.now();
    isDay = now.hour >= 6 && now.hour < 18;
    notifyListeners();
  }

  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String entriesJson = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('entries', entriesJson);
    await prefs.setBool('is24Hour', is24Hour);
    await prefs.setBool('isTableView', isTableView);
    await prefs.setString('language', locale.languageCode);
  }

  void togglePeriod() {
    isDay = !isDay;
    notifyListeners();
    saveData();
  }

  void toggleButton() {
    if (isDormiu) {
      SleepEntry entry = SleepEntry(
        slept: DateTime.now(),
        isDay: isDay,
        bottle: isDay,
      );
      entries.insert(0, entry);
    } else {
      if (entries.isNotEmpty) {
        entries[0].wokeUp = DateTime.now();
      }
    }
    notifyListeners();
    saveData();
  }

  void toggleBottle() {
    if (entries.isNotEmpty) {
      entries[0].bottle = !entries[0].bottle;
      notifyListeners();
      saveData();
    }
  }

  void editBottleTime(int index, DateTime? newTime) {
    if (index >= 0 && index < entries.length) {
      entries[index].bottleTime = newTime;
      if (newTime != null) {
        entries[index].bottle = true;
      }
      notifyListeners();
      saveData();
    }
  }

  void selectRow(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void updateSelectedPeriod() {
    if (selectedIndex != null) {
      entries[selectedIndex!].isDay = !entries[selectedIndex!].isDay;
      notifyListeners();
      saveData();
    }
  }

  void updateEntryPeriod(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].isDay = !entries[index].isDay;
      notifyListeners();
      saveData();
    }
  }

  void updateSelectedBottle(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].bottle = !entries[index].bottle;
      notifyListeners();
      saveData();
    }
  }

  void toggleEntryExpanded(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].isExpanded = !entries[index].isExpanded;
      notifyListeners();
      saveData();
    }
  }

  void editWokeUp(int index, DateTime newTime) {
    entries[index].wokeUp = newTime;
    notifyListeners();
    saveData();
  }

  void editSlept(int index, DateTime newTime) {
    entries[index].slept = newTime;
    notifyListeners();
    saveData();
  }

  void set24Hour(bool value) {
    is24Hour = value;
    notifyListeners();
    saveData();
  }

  void setLanguage(String lang) {
    locale = Locale(lang);
    notifyListeners();
    saveData();
  }

  void toggleViewMode() {
    isTableView = !isTableView;
    notifyListeners();
    saveData();
  }

  Future<String> exportCsv({
    required List<String> headers,
    required String dayValue,
    required String nightValue,
  }) async {
    List<List<String>> rows = [
      headers,
    ];
    for (int i = 0; i < entries.length; i++) {
      SleepEntry e = entries[i];
      String wokeUpStr = '';
      if (e.wokeUp != null) {
        wokeUpStr = DateFormat(is24Hour ? 'dd-MMM yyyy HH:mm' : 'dd-MMM yyyy h:mm a', locale.languageCode == 'pt' ? 'pt_BR' : 'en').format(e.wokeUp!);
      }
      String sleptStr = '';
      if (e.slept != null) {
        sleptStr = DateFormat(is24Hour ? 'dd-MMM yyyy HH:mm' : 'dd-MMM yyyy h:mm a', locale.languageCode == 'pt' ? 'pt_BR' : 'en').format(e.slept!);
      }
      rows.add([
        e.getSleepTime(entries, i),
        e.getAwakeTime(entries, i),
        wokeUpStr.isNotEmpty ? wokeUpStr : e.getFormattedWokeUp(locale, is24Hour),
        sleptStr.isNotEmpty ? sleptStr : e.getFormattedSlept(locale, is24Hour),
        e.isDay ? dayValue : nightValue,
        e.bottle ? (locale.languageCode == 'pt' ? 'Sim' : 'Yes') : (locale.languageCode == 'pt' ? 'Não' : 'No'),
        e.getFormattedBottleTime(locale, is24Hour),
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    
    // Get Downloads directory
    Directory? downloadsDir;
    try {
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    // Create timestamp
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String filename = 'dante_sleep_$timestamp.csv';

    File file = File('${downloadsDir!.path}/$filename');
    await file.writeAsString(csv);
    debugPrint('Exported to ${file.path}');
    return filename;
  }

  Future<int?> importCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return null;

      String? filePath = result.files.single.path;
      if (filePath == null) return null;

      String csvContent = await File(filePath).readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);
      final List<SleepEntry> importedEntries = [];

      // Skip header row if present
      int startIndex = 0;
      if (rows.isNotEmpty &&
          (rows[0][0].toString().toLowerCase().contains('sleep') ||
              rows[0][0].toString().toLowerCase().contains('tempo'))) {
        startIndex = 1;
      }

      for (int i = startIndex; i < rows.length; i++) {
        List<dynamic> row = rows[i];
        if (row.length >= 4) {
          try {
            DateTime? slept;
            DateTime? wokeUp;
            bool isDay = true;
            bool bottle = false;

            DateTime? bottleTime;

            // Expected format: Sleep Time, Awake Time, Woke Up, Slept, Period, Bottle, Bottle Time
            if (row.length > 3 && row[3].toString().isNotEmpty) {
              slept = _parseDateTime(row[3].toString());
            }
            if (row.length > 2 && row[2].toString().isNotEmpty) {
              wokeUp = _parseDateTime(row[2].toString());
            }
            if (row.length > 4 && row[4].toString().isNotEmpty) {
              isDay = row[4].toString().toLowerCase().contains('day') || row[4].toString().toLowerCase().contains('dia');
            }
            if (row.length > 5 && row[5].toString().isNotEmpty) {
              String b = row[5].toString().toLowerCase();
              bottle = b == 'true' || b == 'yes' || b == 'sim';
            }
            if (row.length > 6 && row[6].toString().isNotEmpty) {
              bottleTime = _parseDateTime(row[6].toString());
            }

            if (slept != null || wokeUp != null) {
              importedEntries.add(
                SleepEntry(
                  slept: slept,
                  wokeUp: wokeUp,
                  isDay: isDay,
                  bottle: bottle,
                  bottleTime: bottleTime,
                ),
              );
            }
          } catch (e) {
            debugPrint('Error parsing row $i: $e');
          }
        }
      }

      // Sort entries by slept date (newest first)
      importedEntries.sort((a, b) {
        if (a.slept == null && b.slept == null) return 0;
        if (a.slept == null) return 1;
        if (b.slept == null) return -1;
        return b.slept!.compareTo(a.slept!);
      });

      // Replace all existing records with imported records.
      entries = importedEntries;
      selectedIndex = null;

      notifyListeners();
      saveData();
      return importedEntries.length;
    } catch (e) {
      debugPrint('Error importing CSV: $e');
      return null;
    }
  }

  DateTime? _parseDateTime(String dateStr) {
    try {
      // Try common formats
      List<String> formats = [
        'dd-MMM yyyy HH:mm',
        'dd-MMM HH:mm',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'dd/MM/yyyy HH:mm',
        'MM/dd/yyyy HH:mm',
      ];

      for (String format in formats) {
        try {
          DateTime parsed = DateFormat(format, 'pt_BR').parse(dateStr);
          if (!format.contains('yyyy') && !format.contains('yy')) {
            parsed = DateTime(DateTime.now().year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
          }
          return parsed;
        } catch (_) {
          try {
            DateTime parsed = DateFormat(format, 'en').parse(dateStr);
            if (!format.contains('yyyy') && !format.contains('yy')) {
              parsed = DateTime(DateTime.now().year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
            }
            return parsed;
          } catch (_) {
            continue;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void deleteEntry(int index) {
    entries.removeAt(index);
    selectedIndex = null;
    notifyListeners();
    saveData();
  }

  void clearSelection() {
    selectedIndex = null;
    notifyListeners();
  }
}
