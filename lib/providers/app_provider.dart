import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';
import '../models/sync_queue_item.dart';
import '../services/firebase_service.dart';

class AppProvider with ChangeNotifier {
  List<SleepEntry> entries = [];
  List<SyncQueueItem> _syncQueue = [];
  bool _isMigratingData = false;

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
  Locale locale = ui.PlatformDispatcher.instance.locale.languageCode == 'en' 
      ? const Locale('en') 
      : const Locale('pt');
  int? selectedIndex;

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final user = FirebaseService().currentUser;
    final uidKey = user != null ? '_${user.uid}' : '';

    // Load entries from local storage
    String? entriesJson = prefs.getString('entries$uidKey');
    
    // Migration for existing users that update the app
    if (entriesJson == null && user != null) {
      entriesJson = prefs.getString('entries');
      if (entriesJson != null) {
        prefs.setString('entries$uidKey', entriesJson);
        prefs.remove('entries'); // Clean up old global key
      }
    }

    if (entriesJson != null) {
      List<dynamic> list = jsonDecode(entriesJson);
      entries = list.map((e) => SleepEntry.fromJson(e)).toList();
    }

    // Load sync queue
    await _loadSyncQueue();

    // Try to load settings and entries from Firestore first
    try {
      final user = FirebaseService().currentUser;
      if (user != null) {
        await loadSettingsFromCurrentUser();
        return; // Successfully loaded from Firestore
      }
    } catch (_) {
      // Silently fall through to SharedPreferences
    }

    // Fallback: load from SharedPreferences
    is24Hour = prefs.getBool('is24Hour$uidKey') ?? true;
    isTableView = false;
    String lang = prefs.getString('language$uidKey') ?? 
        (ui.PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'pt');
    locale = Locale(lang);
    
    DateTime now = DateTime.now();
    isDay = now.hour >= 6 && now.hour < 18;
    notifyListeners();
  }

  Future<void> loadSettingsFromCurrentUser() async {
    try {
      final user = FirebaseService().currentUser;
      if (user != null) {
        final firestoreSettings = await FirebaseService().getSettings(user.uid);
        if (firestoreSettings.isNotEmpty) {
          is24Hour = firestoreSettings['timeFormat24h'] ?? true;
          String lang = firestoreSettings['language'] ?? 
              (ui.PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'pt');
          locale = Locale(lang);
        }
        
        // Load entries from Firestore
        final entriesData = await FirebaseService().getSleepEntries(user.uid);
        if (entriesData.isNotEmpty) {
           final List<SleepEntry> loadedEntries = [];
           entriesData.forEach((id, entryData) {
             try {
                final entry = SleepEntry.fromJson(Map<String, dynamic>.from(entryData));
                entry.firestoreId = id;
                entry.syncStatus = 'synced';
                loadedEntries.add(entry);
             } catch (e) {
                debugPrint('Error parsing entry $id: $e');
             }
           });
           
           // Sort by slept time (newest first)
           loadedEntries.sort((a, b) {
             if (a.slept == null && b.slept == null) return 0;
             if (a.slept == null) return 1;
             if (b.slept == null) return -1;
             return b.slept!.compareTo(a.slept!);
           });
           
           entries = loadedEntries;
           await saveData();
        }

        notifyListeners();
        
        // Trigger migration of old entries
        await _migrateOldEntriesToFirestore();
        
        // Trigger sync of any pending operations
        await _syncToFirestore();
      }
    } catch (e) {
      debugPrint('Error loading settings from current user: $e');
    }
  }

  void clearUserData() {
    entries.clear();
    selectedIndex = null;
    _syncQueue.clear();
    notifyListeners();
  }

  Future<void> saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = FirebaseService().currentUser;
    final uidKey = user != null ? '_${user.uid}' : '';
    
    String entriesJson = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('entries$uidKey', entriesJson);
    await prefs.setBool('is24Hour$uidKey', is24Hour);
    await prefs.setBool('isTableView$uidKey', isTableView);
    await prefs.setString('language$uidKey', locale.languageCode);
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
        syncStatus: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      entries.insert(0, entry);
      _addToSyncQueue('create', entry);
    } else {
      if (entries.isNotEmpty) {
        entries[0].wokeUp = DateTime.now();
        entries[0].syncStatus = 'pending';
        entries[0].updatedAt = DateTime.now();
        _addToSyncQueue('update', entries[0]);
      }
    }
    notifyListeners();
    saveData();
    _syncToFirestore();
  }

  void toggleBottle() {
    if (entries.isNotEmpty) {
      entries[0].bottle = !entries[0].bottle;
      entries[0].syncStatus = 'pending';
      entries[0].updatedAt = DateTime.now();
      notifyListeners();
      saveData();
      _addToSyncQueue('update', entries[0]);
      _syncToFirestore();
    }
  }

  void editBottleTime(int index, DateTime? newTime) {
    if (index >= 0 && index < entries.length) {
      entries[index].bottleTime = newTime;
      if (newTime != null) {
        entries[index].bottle = true;
      }
      entries[index].syncStatus = 'pending';
      entries[index].updatedAt = DateTime.now();
      notifyListeners();
      saveData();
      _addToSyncQueue('update', entries[index]);
      _syncToFirestore();
    }
  }

  void selectRow(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void updateSelectedPeriod() {
    if (selectedIndex != null) {
      entries[selectedIndex!].isDay = !entries[selectedIndex!].isDay;
      entries[selectedIndex!].syncStatus = 'pending';
      entries[selectedIndex!].updatedAt = DateTime.now();
      notifyListeners();
      saveData();
      _addToSyncQueue('update', entries[selectedIndex!]);
      _syncToFirestore();
    }
  }

  void updateEntryPeriod(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].isDay = !entries[index].isDay;
      entries[index].syncStatus = 'pending';
      entries[index].updatedAt = DateTime.now();
      notifyListeners();
      saveData();
      _addToSyncQueue('update', entries[index]);
      _syncToFirestore();
    }
  }

  void updateSelectedBottle(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].bottle = !entries[index].bottle;
      entries[index].syncStatus = 'pending';
      entries[index].updatedAt = DateTime.now();
      notifyListeners();
      saveData();
      _addToSyncQueue('update', entries[index]);
      _syncToFirestore();
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
    entries[index].syncStatus = 'pending';
    entries[index].updatedAt = DateTime.now();
    notifyListeners();
    saveData();
    _addToSyncQueue('update', entries[index]);
    _syncToFirestore();
  }

  void editSlept(int index, DateTime newTime) {
    entries[index].slept = newTime;
    entries[index].syncStatus = 'pending';
    entries[index].updatedAt = DateTime.now();
    notifyListeners();
    saveData();
    _addToSyncQueue('update', entries[index]);
    _syncToFirestore();
  }

  void set24Hour(bool value) {
    is24Hour = value;
    notifyListeners();
    saveData();
    _syncSettingsToFirestore();
  }

  void setLanguage(String lang) {
    locale = Locale(lang);
    notifyListeners();
    saveData();
    _syncSettingsToFirestore();
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
      
      _syncImportedEntries(importedEntries);
      
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
    if (index >= 0 && index < entries.length) {
      final entry = entries[index];
      entries.removeAt(index);
      selectedIndex = null;
      notifyListeners();
      saveData();
      if (entry.firestoreId != null) {
        _addToSyncQueue('delete', entry);
      }
      _syncToFirestore();
    }
  }

  void clearSelection() {
    selectedIndex = null;
    notifyListeners();
  }

  Future<void> _syncSettingsToFirestore() async {
    try {
      final user = FirebaseService().currentUser;
      if (user != null) {
        await FirebaseService().updateSettings(user.uid, {
          'language': locale.languageCode,
          'timeFormat24h': is24Hour,
        });
      }
    } catch (e) {
      debugPrint('Error syncing settings to Firestore: $e');
      // Silently fail - settings remain locally but will sync on retry
    }
  }

  void _addToSyncQueue(String operation, SleepEntry entry) {
    final item = SyncQueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      operation: operation,
      entryId: entry.firestoreId ?? '',
      data: entry.toFirestore(),
      createdAt: DateTime.now(),
    );
    _syncQueue.add(item);
    _saveSyncQueue();
  }

  Future<void> _syncToFirestore() async {
    try {
      final user = FirebaseService().currentUser;
      if (user == null) return;

      for (var item in _syncQueue.where((i) => i.status == 'pending')) {
        try {
          item.status = 'syncing';

          switch (item.operation) {
            case 'create':
              final docId = await FirebaseService().createSleepEntry(user.uid, item.data);
              // Update local entry with Firebase ID
              final entryIndex = entries.indexWhere((e) => e.firestoreId == null && e.createdAt == DateTime.parse(item.data['createdAt']));
              if (entryIndex >= 0) {
                entries[entryIndex].firestoreId = docId;
              }
              item.entryId = docId;
              item.status = 'synced';
              break;

            case 'update':
              if (item.entryId.isNotEmpty) {
                await FirebaseService().updateSleepEntry(user.uid, item.entryId, item.data);
                item.status = 'synced';
              }
              break;

            case 'delete':
              if (item.entryId.isNotEmpty) {
                await FirebaseService().deleteSleepEntry(user.uid, item.entryId);
                item.status = 'synced';
              }
              break;
          }
        } catch (e) {
          debugPrint('Error syncing item ${item.id}: $e');
          item.status = 'failed';
        }
      }

      // Remove synced items
      _syncQueue.removeWhere((i) => i.status == 'synced');
      _saveSyncQueue();

      // Mark entries as synced
      for (var entry in entries.where((e) => e.syncStatus == 'pending')) {
        entry.syncStatus = 'synced';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error in _syncToFirestore: $e');
    }
  }

  Future<void> _loadSyncQueue() async {
    try {
      final user = FirebaseService().currentUser;
      final uidKey = user != null ? '_${user.uid}' : '';
      final prefs = await SharedPreferences.getInstance();
      
      String? queueJson = prefs.getString('sync_queue$uidKey');
      if (queueJson == null && user != null) {
        // Migration
        queueJson = prefs.getString('sync_queue');
        if (queueJson != null) {
          prefs.setString('sync_queue$uidKey', queueJson);
          prefs.remove('sync_queue');
        }
      }

      if (queueJson != null) {
        final List<dynamic> list = jsonDecode(queueJson);
        _syncQueue = list
            .map((e) => SyncQueueItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  Future<void> _saveSyncQueue() async {
    try {
      final user = FirebaseService().currentUser;
      final uidKey = user != null ? '_${user.uid}' : '';
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_syncQueue.map((e) => e.toJson()).toList());
      await prefs.setString('sync_queue$uidKey', queueJson);
    } catch (e) {
      debugPrint('Error saving sync queue: $e');
    }
  }

  Future<void> _migrateOldEntriesToFirestore() async {
    if (_isMigratingData) return;

    try {
      final user = FirebaseService().currentUser;
      if (user == null) return;

      // Check if already migrated
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('entries_migrated_$user.uid') ?? false) return;

      _isMigratingData = true;

      // Get old entries from SharedPreferences
      final entriesJson = prefs.getString('entries');
      if (entriesJson != null && entriesJson.isNotEmpty) {
        List<dynamic> list = jsonDecode(entriesJson);
        List<Map<String, dynamic>> entriesToMigrate = [];

        for (var e in list) {
          final entry = SleepEntry.fromJson(e);
          entriesToMigrate.add(entry.toFirestore());
        }

        if (entriesToMigrate.isNotEmpty) {
          await FirebaseService().migrateSleepEntriesToFirestore(user.uid, entriesToMigrate);
          await prefs.setBool('entries_migrated_${user.uid}', true);
          debugPrint('Migrated ${entriesToMigrate.length} entries to Firestore');
        }
      }

      _isMigratingData = false;
    } catch (e) {
      debugPrint('Error migrating entries: $e');
      _isMigratingData = false;
    }
  }

  Future<void> _syncImportedEntries(List<SleepEntry> importedEntries) async {
    try {
      final user = FirebaseService().currentUser;
      if (user == null) return;

      // Clear pending sync queue items since we are replacing the entire database
      _syncQueue.clear();
      _saveSyncQueue();

      final entriesData = importedEntries.map((e) {
        e.syncStatus = 'synced';
        return e.toFirestore();
      }).toList();
      
      final ids = await FirebaseService().replaceAllSleepEntries(user.uid, entriesData);
      
      for (int i = 0; i < importedEntries.length; i++) {
        importedEntries[i].firestoreId = ids[i];
      }
      saveData();
      notifyListeners();
    } catch (e) {
      debugPrint('Error syncing imported CSV to Firebase: $e');
      // If bulk sync fails, fallback to adding to queue so it tries later
      for (var entry in importedEntries) {
         _addToSyncQueue('create', entry);
      }
    }
  }
}
