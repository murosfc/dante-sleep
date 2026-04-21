import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';

class AppProvider with ChangeNotifier {
  List<SleepEntry> entries = [];
  bool isDormiu = true;
  bool isDay = true;
  bool is24Hour = true;
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
    await prefs.setString('language', locale.languageCode);
  }

  void togglePeriod() {
    isDay = !isDay;
    notifyListeners();
    saveData();
  }

  void toggleButton() {
    if (isDormiu) {
      SleepEntry entry = SleepEntry(slept: DateTime.now(), isDay: isDay);
      entries.insert(0, entry);
    } else {
      if (entries.isNotEmpty) {
        entries[0].wokeUp = DateTime.now();
      }
    }
    isDormiu = !isDormiu;
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

  void updateSelectedBottle() {
    if (selectedIndex != null) {
      entries[selectedIndex!].bottle = !entries[selectedIndex!].bottle;
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

  Future<String> exportCsv() async {
    List<List<String>> rows = [
      ['Sleep Time', 'Awake Time', 'Woke Up', 'Slept', 'Period', 'Bottle'],
    ];
    for (int i = 0; i < entries.length; i++) {
      SleepEntry e = entries[i];
      rows.add([
        e.getSleepTime(entries, i),
        e.getAwakeTime(entries, i),
        e.getFormattedWokeUp(locale, is24Hour),
        e.getFormattedSlept(locale, is24Hour),
        e.isDay ? 'Day' : 'Night',
        e.bottle ? 'Yes' : 'No',
      ]);
    }
    String csv = const ListToCsvConverter().convert(rows);
    Directory dir = await getApplicationDocumentsDirectory();
    String filename = 'dante_sleep_export.csv';
    File file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    debugPrint('Exported to ${file.path}');
    return filename;
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
