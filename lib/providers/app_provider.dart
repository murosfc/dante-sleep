import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';
import '../models/sync_queue_item.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

class AppProvider with ChangeNotifier {
  List<SleepEntry> entries = [];
  List<SyncQueueItem> _syncQueue = [];
  bool _isMigratingData = false;
  String? _sleepWindowPredictions = '';
  Timer? _aiRefreshTimer;

  void _scheduleAiRefresh() {
    _aiRefreshTimer?.cancel();
    _aiRefreshTimer = Timer(const Duration(seconds: 30), () {
      refreshAiSuggestions();
    });
  }

  void _updateWidget() {
    WidgetService.updateHomeScreenWidget(
      entries: entries,
      locale: locale,
      is24Hour: is24Hour,
      babyName: babyProfile?.name,
      isLightTheme: isVisualDay,
    );
  }

  // ─── Baby profile & AI ────────────────────────────────────────────────────
  BabyProfile? babyProfile;
  String? userDisplayName;
  bool babyProfileLoaded = false;
  String? _loadedUserId;
  bool _isLoadingAuthUserData = false;
  String? get loadedUserId => _loadedUserId;
  bool get isLoadingAuthUserData => _isLoadingAuthUserData;
  AiSuggestion? aiSuggestion;
  int get aiUnreadCount {
    if (aiSuggestion == null || !aiSuggestion!.hasContent) return 0;
    return (aiSuggestion!.nextNapTime != null ? 1 : 0) +
        (aiSuggestion!.bedtimeRoutineStart != null ? 1 : 0) +
        (aiSuggestion!.nightWakeTime != null ? 1 : 0);
  }

  bool _aiSuggestionsRead = false;
  String get nvidiaApiKeyFromEnv {
    final primary = (dotenv.env['NVIDIA_API_KEY'] ?? '').trim();
    if (primary.isNotEmpty) return primary;
    return const String.fromEnvironment('NVIDIA_API_KEY');
  }

  String? get nvidiaModelFromEnv {
    final value = (dotenv.env['NVIDIA_MODEL'] ?? '').trim();
    return value.isEmpty ? null : value;
  }

  String? get sleepWindowPredictions => _sleepWindowPredictions;
  bool get hasNvidiaApiKeyConfigured => nvidiaApiKeyFromEnv.isNotEmpty;
  bool get hasPendingAiNotifications =>
      !_aiSuggestionsRead && aiUnreadCount > 0;
  void markAiSuggestionsRead() {
    _aiSuggestionsRead = true;
    notifyListeners();
  }

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
  String visualThemeMode = 'auto'; // 'auto' | 'day' | 'night'
  Locale locale = _systemDefaultLocale();
  int? selectedIndex;

  bool get isVisualDay {
    if (visualThemeMode == 'day') return true;
    if (visualThemeMode == 'night') return false;
    return isDay; // auto: follows the day/night period button
  }

  static Locale _systemDefaultLocale() {
    try {
      final code = ui.PlatformDispatcher.instance.locale.languageCode
          .trim()
          .toLowerCase();
      if (code == 'pt') return const Locale('pt', 'BR');
      return const Locale('en');
    } catch (_) {
      return const Locale('pt', 'BR');
    }
  }

  static Locale _localeFromStoredLanguage(String? lang) {
    final value = (lang ?? '').trim().toLowerCase();
    if (value.startsWith('pt')) return const Locale('pt', 'BR');
    if (value.startsWith('en')) return const Locale('en');
    return const Locale('pt', 'BR');
  }

  static String _storedLanguageFromLocale(Locale locale) {
    return locale.languageCode == 'pt' ? 'pt-BR' : 'en';
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final user = FirebaseService().currentUser;
    final uidKey = user != null ? '_${user.uid}' : '';

    // Load only sync queue locally (entries come from Firestore)
    await _loadSyncQueue();

    if (user != null) {
      // Load settings + entries + baby profile from Firestore
      try {
        await loadSettingsFromCurrentUser();
        return;
      } catch (_) {
        // Fall through to local settings fallback
      }
    }

    // No user or Firestore unavailable — load prefs only
    is24Hour = prefs.getBool('is24Hour$uidKey') ?? true;
    String lang =
        prefs.getString('language$uidKey') ??
        _storedLanguageFromLocale(_systemDefaultLocale());
    visualThemeMode = prefs.getString('visualThemeMode$uidKey') ?? 'auto';
    locale = _localeFromStoredLanguage(lang);
    DateTime now = DateTime.now();
    isDay = now.hour >= 6 && now.hour < 18;
    _loadedUserId = null;
    babyProfileLoaded = true;
    notifyListeners();
    _updateWidget();
  }

  Future<void> ensureUserDataLoadedFor(User user) async {
    if (_loadedUserId == user.uid && babyProfileLoaded) return;
    if (_isLoadingAuthUserData) return;

    _isLoadingAuthUserData = true;

    // Prevent showing stale data from previous account.
    if (_loadedUserId != user.uid) {
      entries = [];
      babyProfile = null;
      userDisplayName = null;
      aiSuggestion = null;
      _aiSuggestionsRead = false;
    }

    babyProfileLoaded = false;
    notifyListeners();

    try {
      await loadSettingsFromCurrentUser();
      _loadedUserId = user.uid;
    } finally {
      _isLoadingAuthUserData = false;
      notifyListeners();
    }
  }

  Future<void> loadSettingsFromCurrentUser() async {
    try {
      final user = FirebaseService().currentUser;
      if (user == null) {
        _loadedUserId = null;
        babyProfileLoaded = true;
        notifyListeners();
        return;
      }

      // 1. Settings
      final firestoreSettings = await FirebaseService().getSettings(user.uid);
      if (firestoreSettings.isNotEmpty) {
        is24Hour = firestoreSettings['timeFormat24h'] ?? true;
        final lang =
            (firestoreSettings['language'] as String?) ??
            _storedLanguageFromLocale(_systemDefaultLocale());
        visualThemeMode =
            (firestoreSettings['visualThemeMode'] as String?) ?? 'auto';
        locale = _localeFromStoredLanguage(lang);
        
        // Save to SharedPreferences so local settings are synchronized
        await saveData();
      }

      // 1.1 User profile
      final userProfile = await FirebaseService().getUserProfile(user.uid);
      userDisplayName = (userProfile['displayName'] as String?)?.trim();
      if (userDisplayName?.isEmpty == true) {
        userDisplayName = null;
      }

      // 2. Entries — Firestore is the ONLY source of truth
      final entriesData = await FirebaseService().getSleepEntries(user.uid);
      final loaded = <SleepEntry>[];
      entriesData.forEach((id, entryData) {
        try {
          final entry = SleepEntry.fromJson(
            Map<String, dynamic>.from(entryData as Map),
          );
          entry.firestoreId = id;
          entry.syncStatus = 'synced';
          loaded.add(entry);
        } catch (e) {
          debugPrint('Error parsing entry $id: $e');
        }
      });
      loaded.sort((a, b) {
        if (a.slept == null && b.slept == null) return 0;
        if (a.slept == null) return 1;
        if (b.slept == null) return -1;
        return b.slept!.compareTo(a.slept!);
      });
      entries = loaded;
      _sleepWindowPredictions = '';

      // 3. Baby profile
      final babyData = await FirebaseService().getBabyData(user.uid);
      if (babyData != null) {
        try {
          babyProfile = BabyProfile.fromFirestore(babyData);
        } catch (e) {
          debugPrint('Error parsing baby profile: $e');
          babyProfile = null;
        }
      } else {
        babyProfile = null;
      }
      _loadedUserId = user.uid;
      babyProfileLoaded = true;

      notifyListeners();
      _updateWidget();

      // 4. Migration (legacy local → Firestore) + pending sync
      await _migrateOldEntriesToFirestore();
      await _syncToFirestore();

      // 5. Refresh AI suggestions if API key is configured
      if (hasNvidiaApiKeyConfigured && babyProfile != null) {
        refreshAiSuggestions();
      }
    } catch (e) {
      debugPrint('Error loading settings from current user: $e');
      final user = FirebaseService().currentUser;
      if (user != null) {
        _loadedUserId = user.uid;
      }
      babyProfileLoaded = true;
      notifyListeners();
    }
  }

  // ─── Baby profile ──────────────────────────────────────────────────────────
  Future<void> saveBabyProfile(BabyProfile profile) async {
    babyProfile = profile;
    babyProfileLoaded = true;
    notifyListeners();
    try {
      final user = FirebaseService().currentUser;
      if (user != null) {
        await FirebaseService().saveBabyData(user.uid, profile.toFirestore());
      }
    } catch (e) {
      debugPrint('Error saving baby profile: $e');
    }
  }

  // ─── AI suggestions ────────────────────────────────────────────────────────
  Future<void> refreshAiSuggestions() async {
    final profile = babyProfile;
    final apiKey = nvidiaApiKeyFromEnv;
    if (apiKey.isEmpty) {
      debugPrint(
        'AI suggestion error: NVIDIA_API_KEY missing (.env or --dart-define).',
      );
      aiSuggestion = const AiSuggestion(
        error:
            'NVIDIA_API_KEY não encontrada. Configure .env ou --dart-define=NVIDIA_API_KEY.',
      );
      notifyListeners();
      return;
    }
    if (profile == null) {
      debugPrint('AI suggestion error: baby profile not found.');
      aiSuggestion = const AiSuggestion(
        error: 'Perfil do bebê não encontrado. Complete o onboarding.',
      );
      notifyListeners();
      return;
    }

    _aiSuggestionsRead = false;
    aiSuggestion = const AiSuggestion.loading();
    notifyListeners();

    final isNightMode = _isNightContext();
    if (isNightMode) {
      final nightForecast = _calculateNightWakeForecast(
        profile,
        isPt: locale.languageCode == 'pt',
      );
      aiSuggestion = AiSuggestion(
        nextNapTime: null,
        nextNapRationale: null,
        bedtimeRoutineStart: null,
        bedtimeRationale: null,
        nightWakeTime: nightForecast.time,
        nightWakeRationale: nightForecast.rationale,
        generatedAt: DateTime.now(),
      );
      notifyListeners();

      try {
        await NotificationService.scheduleAiSuggestions(
          napTime: null,
          napRationale: null,
          routineStart: null,
          routineRationale: null,
          nightWakeTime: aiSuggestion!.nightWakeTime,
          nightWakeRationale: aiSuggestion!.nightWakeRationale,
          isPt: locale.languageCode == 'pt',
          userName: userDisplayName,
          babyName: profile.name,
          babySex: profile.sex,
        );
      } catch (e) {
        debugPrint('NotificationService error: $e');
      }
      return;
    }

    final result = await GeminiService.getSuggestions(
      apiKey: apiKey,
      profile: profile,
      entries: entries,
      languageCode: locale.languageCode,
      preferredModel: nvidiaModelFromEnv,
    );

    aiSuggestion = result;
    if (result?.error != null) {
      debugPrint('AI suggestion full error: ${result!.error}');
    }
    aiSuggestion = _removeMorningBridgeNap(aiSuggestion);
    notifyListeners();

    // Schedule local notifications for the suggested times
    if (aiSuggestion != null && aiSuggestion!.error == null) {
      try {
        await NotificationService.scheduleAiSuggestions(
          napTime: aiSuggestion!.nextNapTime,
          napRationale: aiSuggestion!.nextNapRationale,
          routineStart: aiSuggestion!.bedtimeRoutineStart,
          routineRationale: aiSuggestion!.bedtimeRationale,
          nightWakeTime: aiSuggestion!.nightWakeTime,
          nightWakeRationale: aiSuggestion!.nightWakeRationale,
          isPt: locale.languageCode == 'pt',
          userName: userDisplayName,
          babyName: profile.name,
          babySex: profile.sex,
        );
      } catch (e) {
        debugPrint('NotificationService error: $e');
      }
    }
  }

  Future<void> refreshSleepWindowPredictions({bool force = false}) async {
    if (!force && _sleepWindowPredictions != null) return;
    
    // Set to null to show loading state
    _sleepWindowPredictions = null;
    notifyListeners();

    final apiKey = nvidiaApiKeyFromEnv;
    if (apiKey.isEmpty || babyProfile == null) {
      _sleepWindowPredictions = '';
      notifyListeners();
      return;
    }

    try {
      final result = await GeminiService.getSchedulePredictions(
        apiKey: apiKey,
        profile: babyProfile!,
        entries: entries,
        languageCode: locale.languageCode,
        preferredModel: nvidiaModelFromEnv,
      );

      _sleepWindowPredictions = (result != null && result.isNotEmpty) ? result : '';
    } catch (e) {
      debugPrint('Error refreshing sleep predictions: $e');
      _sleepWindowPredictions = '';
    }
    
    notifyListeners();
  }

  bool _isNightContext() {
    if (!isDay) return true;
    if (entries.isEmpty) return false;
    return entries.first.isDay == false;
  }

  AiSuggestion? _removeMorningBridgeNap(AiSuggestion? suggestion) {
    if (suggestion == null) return null;
    final isMorning = DateTime.now().hour < 12;
    if (!isMorning) return suggestion;

    final rationale = (suggestion.nextNapRationale ?? '').toLowerCase();
    final mentionsBridge =
        rationale.contains('ponte') || rationale.contains('bridge');
    if (!mentionsBridge) return suggestion;

    return AiSuggestion(
      nextNapTime: null,
      nextNapRationale: null,
      bedtimeRoutineStart: suggestion.bedtimeRoutineStart,
      bedtimeRationale: suggestion.bedtimeRationale,
      nightWakeTime: suggestion.nightWakeTime,
      nightWakeRationale: suggestion.nightWakeRationale,
      generatedAt: suggestion.generatedAt,
      isLoading: suggestion.isLoading,
      error: suggestion.error,
    );
  }

  ({String time, String rationale}) _calculateNightWakeForecast(
    BabyProfile profile, {
    required bool isPt,
  }) {
    final firstNightSleep = _findCurrentNightStart();
    if (firstNightSleep == null) {
      final fallback = _fallbackNightDuration(profile);
      final wake = DateTime.now().add(fallback);
      return (
        time: _formatHm(wake),
        rationale: isPt
            ? 'Previsão baseada na duração noturna esperada para a idade (${fallback.inHours}h).'
            : 'Forecast based on expected night sleep duration for age (${fallback.inHours}h).',
      );
    }

    final avgDuration = _averageCompletedNightDuration();
    final baseline = avgDuration ?? _fallbackNightDuration(profile);
    final wake = firstNightSleep.add(baseline);

    final sourceText = avgDuration != null
        ? (isPt ? 'média das noites anteriores' : 'average of previous nights')
        : (isPt ? 'referência por idade' : 'age fallback');

    return (
      time: _formatHm(wake),
      rationale: isPt
          ? 'Previsão de acordar às ${_formatHm(wake)} usando $sourceText.'
          : 'Forecast wake-up at ${_formatHm(wake)} using $sourceText.',
    );
  }

  DateTime? _findCurrentNightStart() {
    for (final entry in entries) {
      if (!entry.isDay && entry.slept != null) {
        return entry.slept;
      }
      if (entry.isDay) {
        break;
      }
    }
    return null;
  }

  Duration? _averageCompletedNightDuration() {
    final durations = <Duration>[];
    for (final entry in entries) {
      if (!entry.isDay && entry.slept != null && entry.wokeUp != null) {
        final diff = entry.wokeUp!.difference(entry.slept!);
        if (!diff.isNegative) {
          durations.add(diff);
        }
      }
      if (durations.length >= 14) break;
    }

    if (durations.isEmpty) return null;
    final totalMinutes = durations.fold<int>(0, (sum, d) => sum + d.inMinutes);
    return Duration(minutes: (totalMinutes / durations.length).round());
  }

  Duration _fallbackNightDuration(BabyProfile profile) {
    final range = SleepKnowledgeBase.getRecommendedNightSleepHours(
      profile.birthdate,
    );
    final avgHours = (range.minHours + range.maxHours) / 2;
    return Duration(minutes: (avgHours * 60).round());
  }

  String _formatHm(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void clearUserData() {
    entries.clear();
    selectedIndex = null;
    _syncQueue.clear();
    babyProfile = null;
    userDisplayName = null;
    aiSuggestion = null;
    _aiSuggestionsRead = false;
    _loadedUserId = null;
    babyProfileLoaded = false;
    notifyListeners();
    _updateWidget();
  }

  /// Persists only user preferences (settings) locally.
  /// Entries are NOT stored locally — Firestore is the single source of truth.
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseService().currentUser;
    final uidKey = user != null ? '_${user.uid}' : '';
    await prefs.setBool('is24Hour$uidKey', is24Hour);
    await prefs.setBool('isTableView$uidKey', isTableView);
    await prefs.setString('language$uidKey', _storedLanguageFromLocale(locale));
    await prefs.setString('visualThemeMode$uidKey', visualThemeMode);
  }

  void setVisualThemeMode(String mode) {
    if (mode != 'auto' && mode != 'day' && mode != 'night') return;
    visualThemeMode = mode;
    notifyListeners();
    _updateWidget();
    saveData();
    _syncSettingsToFirestore();
  }

  void checkAndAutoUpdateDayNight() {
    DateTime now = DateTime.now();
    if (now.hour >= 18 && isDay) {
      isDay = false;
      notifyListeners();
      _updateWidget();
    } else if (now.hour >= 6 && now.hour < 18 && !isDay) {
      isDay = true;
      notifyListeners();
      _updateWidget();
    }
  }

  void togglePeriod() {
    isDay = !isDay;
    notifyListeners();
    _updateWidget();
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
    _updateWidget();
    _syncToFirestore();
    // Refresh AI suggestions after every sleep event (delayed by 30s)
    _scheduleAiRefresh();
    _sleepWindowPredictions = '';

    // Auto-fetch AI full schedule only if the baby just woke up from a night sleep (start of the day)
    if (!isDormiu && entries.isNotEmpty && !entries[0].isDay) {
      refreshSleepWindowPredictions(force: true);
    }
  }

  void toggleBottle() {
    if (entries.isNotEmpty) {
      entries[0].bottle = !entries[0].bottle;
      entries[0].syncStatus = 'pending';
      entries[0].updatedAt = DateTime.now();
      notifyListeners();
      _addToSyncQueue('update', entries[0]);
      _syncToFirestore();
    }
  }

  void editBottleTime(int index, DateTime? newTime) {
    if (index >= 0 && index < entries.length) {
      entries[index].bottleTime = newTime;
      if (newTime != null) entries[index].bottle = true;
      entries[index].syncStatus = 'pending';
      entries[index].updatedAt = DateTime.now();
      notifyListeners();
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
      _addToSyncQueue('update', entries[index]);
      _syncToFirestore();
    }
  }

  void toggleEntryExpanded(int index) {
    if (index >= 0 && index < entries.length) {
      entries[index].isExpanded = !entries[index].isExpanded;
      notifyListeners();
    }
  }

  void editWokeUp(int index, DateTime newTime) {
    entries[index].wokeUp = newTime;
    entries[index].syncStatus = 'pending';
    entries[index].updatedAt = DateTime.now();
    notifyListeners();
    _updateWidget();
    _addToSyncQueue('update', entries[index]);
    _syncToFirestore();
    _sleepWindowPredictions = '';
    _scheduleAiRefresh();
    
    // Auto-fetch AI full schedule only if it was a night wake up
    if (!entries[index].isDay) {
      refreshSleepWindowPredictions(force: true);
    }
  }

  void editSlept(int index, DateTime newTime) {
    entries[index].slept = newTime;
    entries[index].syncStatus = 'pending';
    entries[index].updatedAt = DateTime.now();
    notifyListeners();
    _updateWidget();
    _addToSyncQueue('update', entries[index]);
    _syncToFirestore();
    _sleepWindowPredictions = '';
    _scheduleAiRefresh();
  }

  void set24Hour(bool value) {
    is24Hour = value;
    notifyListeners();
    _updateWidget();
    saveData();
    _syncSettingsToFirestore();
  }

  void setLanguage(String lang) {
    locale = _localeFromStoredLanguage(lang);
    notifyListeners();
    _updateWidget();
    saveData();
    _syncSettingsToFirestore();
  }

  void toggleViewMode() {
    isTableView = !isTableView;
    notifyListeners();
    saveData(); // Settings only, fine to persist locally
  }

  Future<String> exportCsv({
    required List<String> headers,
    required String dayValue,
    required String nightValue,
  }) async {
    List<List<String>> rows = [headers];
    for (int i = 0; i < entries.length; i++) {
      SleepEntry e = entries[i];
      String wokeUpStr = '';
      if (e.wokeUp != null) {
        wokeUpStr = DateFormat(
          is24Hour ? 'dd-MMM yyyy HH:mm' : 'dd-MMM yyyy h:mm a',
          locale.languageCode == 'pt' ? 'pt_BR' : 'en',
        ).format(e.wokeUp!);
      }
      String sleptStr = '';
      if (e.slept != null) {
        sleptStr = DateFormat(
          is24Hour ? 'dd-MMM yyyy HH:mm' : 'dd-MMM yyyy h:mm a',
          locale.languageCode == 'pt' ? 'pt_BR' : 'en',
        ).format(e.slept!);
      }
      rows.add([
        e.getSleepTime(entries, i),
        e.getAwakeTime(entries, i),
        wokeUpStr.isNotEmpty
            ? wokeUpStr
            : e.getFormattedWokeUp(locale, is24Hour),
        sleptStr.isNotEmpty ? sleptStr : e.getFormattedSlept(locale, is24Hour),
        e.isDay ? dayValue : nightValue,
        e.bottle
            ? (locale.languageCode == 'pt' ? 'Sim' : 'Yes')
            : (locale.languageCode == 'pt' ? 'Não' : 'No'),
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
              isDay =
                  row[4].toString().toLowerCase().contains('day') ||
                  row[4].toString().toLowerCase().contains('dia');
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
      _updateWidget();
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
            parsed = DateTime(
              DateTime.now().year,
              parsed.month,
              parsed.day,
              parsed.hour,
              parsed.minute,
              parsed.second,
            );
          }
          return parsed;
        } catch (_) {
          try {
            DateTime parsed = DateFormat(format, 'en').parse(dateStr);
            if (!format.contains('yyyy') && !format.contains('yy')) {
              parsed = DateTime(
                DateTime.now().year,
                parsed.month,
                parsed.day,
                parsed.hour,
                parsed.minute,
                parsed.second,
              );
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
      _updateWidget();
      if (entry.firestoreId != null) {
        _addToSyncQueue('delete', entry);
      }
      _syncToFirestore();
      _sleepWindowPredictions = '';
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
          'language': _storedLanguageFromLocale(locale),
          'timeFormat24h': is24Hour,
          'visualThemeMode': visualThemeMode,
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

      for (var item in _syncQueue.where(
        (i) => i.status == 'pending' || i.status == 'failed',
      )) {
        try {
          item.status = 'syncing';

          switch (item.operation) {
            case 'create':
              final docId = await FirebaseService().createSleepEntry(
                user.uid,
                item.data,
              );
              // Update local entry with Firebase ID
              final createdAt = _asDateTime(item.data['createdAt']);
              final entryIndex = entries.indexWhere(
                (e) => e.firestoreId == null && e.createdAt == createdAt,
              );
              if (entryIndex >= 0) {
                entries[entryIndex].firestoreId = docId;
              }
              item.entryId = docId;
              item.status = 'synced';
              break;

            case 'update':
              if (item.entryId.isNotEmpty) {
                await FirebaseService().updateSleepEntry(
                  user.uid,
                  item.entryId,
                  item.data,
                );
                item.status = 'synced';
              }
              break;

            case 'delete':
              if (item.entryId.isNotEmpty) {
                await FirebaseService().deleteSleepEntry(
                  user.uid,
                  item.entryId,
                );
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
          await FirebaseService().migrateSleepEntriesToFirestore(
            user.uid,
            entriesToMigrate,
          );
          await prefs.setBool('entries_migrated_${user.uid}', true);
          debugPrint(
            'Migrated ${entriesToMigrate.length} entries to Firestore',
          );
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

      final ids = await FirebaseService().replaceAllSleepEntries(
        user.uid,
        entriesData,
      );

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

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
