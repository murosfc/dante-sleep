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

import '../knowledge/manual_sleep_plan.dart';
import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';
import '../models/sleep_window_prediction.dart';
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
  Timer? _liveClockTimer;

  AppProvider() {
    // Ticks the UI once a second so the live sleep/awake counter (with
    // seconds) on the most recent card keeps advancing until a new record
    // closes the cycle.
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (entries.isNotEmpty) notifyListeners();
    });
  }

  @override
  void dispose() {
    _liveClockTimer?.cancel();
    _aiRefreshTimer?.cancel();
    super.dispose();
  }

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
      // If we have a local cache of entries/baby profile from a previous
      // session, show it immediately (so the app isn't blocked behind a
      // full Firestore round-trip on every cold start, which gets slower
      // as the entries history grows) and refresh from Firestore in the
      // background.
      final cachedEntries = await _loadEntriesCache(user.uid);
      if (cachedEntries != null) {
        entries = cachedEntries;
        babyProfile = await _loadBabyProfileCache(user.uid);
        is24Hour = prefs.getBool('is24Hour$uidKey') ?? true;
        String lang =
            prefs.getString('language$uidKey') ??
            _storedLanguageFromLocale(_systemDefaultLocale());
        visualThemeMode = prefs.getString('visualThemeMode$uidKey') ?? 'auto';
        locale = _localeFromStoredLanguage(lang);
        _loadedUserId = user.uid;
        babyProfileLoaded = true;
        notifyListeners();
        _updateWidget();
        unawaited(loadSettingsFromCurrentUser());
        return;
      }

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

      // Show cached data instantly (if any) while fresh data loads in the
      // background, instead of blocking on a full Firestore fetch.
      final cachedEntries = await _loadEntriesCache(user.uid);
      if (cachedEntries != null) {
        entries = cachedEntries;
        babyProfile = await _loadBabyProfileCache(user.uid);
        _loadedUserId = user.uid;
        babyProfileLoaded = true;
        _isLoadingAuthUserData = false;
        notifyListeners();
        unawaited(loadSettingsFromCurrentUser());
        return;
      }
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
      unawaited(_saveEntriesCache(user.uid, loaded));

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
      unawaited(_saveBabyProfileCache(user.uid, babyProfile));
      _loadedUserId = user.uid;
      babyProfileLoaded = true;

      notifyListeners();
      _updateWidget();

      // 4. Migration (legacy local → Firestore) + pending sync
      await _migrateOldEntriesToFirestore();
      await _syncToFirestore();

      // 5. Refresh suggestions: AI when a key is configured, or always when
      //    the profile opted into the manual (AI-free) plan.
      if (babyProfile != null &&
          (hasNvidiaApiKeyConfigured || !babyProfile!.useAiSuggestions)) {
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
    if (profile == null) {
      debugPrint('AI suggestion error: baby profile not found.');
      aiSuggestion = const AiSuggestion(
        error: 'Perfil do bebê não encontrado. Complete o onboarding.',
      );
      notifyListeners();
      return;
    }

    // AI disabled: the app computes the schedule itself, no network calls.
    if (!profile.useAiSuggestions) {
      await _refreshManualPlan(profile);
      return;
    }

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

  // ─── Manual (AI-free) sleep plan ───────────────────────────────────────────

  /// Turns AI suggestions on/off. When turning off, the app immediately
  /// recomputes the manual schedule; when turning on, it fetches AI again.
  Future<void> setUseAiSuggestions(bool value) async {
    final profile = babyProfile;
    if (profile == null || profile.useAiSuggestions == value) return;
    profile.useAiSuggestions = value;
    notifyListeners();
    await saveBabyProfile(profile);
    _sleepWindowPredictions = '';
    await refreshAiSuggestions();
  }

  /// Persists the manual plan. [wakeWindowsMinutes] holds 1 entry when
  /// [sameWakeWindow] is true, otherwise [napsPerDay] + 1 entries;
  /// [napDurationsMinutes] holds 1 entry when [sameNapDuration] is true,
  /// otherwise [napsPerDay] entries. The min/max of each list is also mirrored
  /// into the profile's wake-window / nap-duration ranges so the rest of the
  /// app (share estimates, local night forecast) follows the manual numbers.
  Future<void> setManualSleepPlan({
    required int napsPerDay,
    required bool sameWakeWindow,
    required bool sameNapDuration,
    required List<int> wakeWindowsMinutes,
    required List<int> napDurationsMinutes,
  }) async {
    final profile = babyProfile;
    if (profile == null) return;

    profile.manualNapsPerDay = napsPerDay.clamp(0, 6);
    profile.manualSameWakeWindow = sameWakeWindow;
    profile.manualSameNapDuration = sameNapDuration;
    profile.manualWakeWindowsMinutes =
        wakeWindowsMinutes.isEmpty ? [150] : List<int>.from(wakeWindowsMinutes);
    profile.manualNapDurationsMinutes =
        napDurationsMinutes.isEmpty ? [90] : List<int>.from(napDurationsMinutes);

    // Mirror into the shared ranges used elsewhere in the app.
    final resolvedWw = profile.resolvedManualWakeWindowsMinutes;
    final resolvedNd = profile.resolvedManualNapDurationsMinutes;
    if (resolvedWw.isNotEmpty) {
      profile.wakeWindowMinMinutes = resolvedWw.reduce((a, b) => a < b ? a : b);
      profile.wakeWindowMaxMinutes = resolvedWw.reduce((a, b) => a > b ? a : b);
    }
    if (resolvedNd.isNotEmpty) {
      profile.napDurationMinMinutes = resolvedNd.reduce((a, b) => a < b ? a : b);
      profile.napDurationMaxMinutes = resolvedNd.reduce((a, b) => a > b ? a : b);
    }

    notifyListeners();
    await saveBabyProfile(profile);
    if (!profile.useAiSuggestions) {
      await refreshAiSuggestions();
    }
  }

  /// Builds nap/routine hints and schedules notifications from the manual plan.
  /// At night it behaves like the AI path: a single wake-up forecast, no nap
  /// notifications.
  Future<void> _refreshManualPlan(BabyProfile profile) async {
    _aiSuggestionsRead = false;
    aiSuggestion = const AiSuggestion.loading();
    notifyListeners();

    final isPt = locale.languageCode == 'pt';

    if (_isNightContext()) {
      final nightForecast = _calculateNightWakeForecast(profile, isPt: isPt);
      aiSuggestion = AiSuggestion(
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
          isPt: isPt,
          userName: userDisplayName,
          babyName: profile.name,
          babySex: profile.sex,
        );
      } catch (e) {
        debugPrint('NotificationService error: $e');
      }
      return;
    }

    final anchor = _resolveManualAnchor();
    final schedule = ManualSleepPlan.compute(
      anchorTime: anchor.time,
      anchorIsAsleep: anchor.asleep,
      completedNaps: anchor.completedNaps,
      wakeWindowsMinutes: profile.resolvedManualWakeWindowsMinutes,
      napDurationsMinutes: profile.resolvedManualNapDurationsMinutes,
    );

    final now = DateTime.now();
    final nextNap = schedule.nextNap(now);
    final totalNaps = profile.manualNapsPerDay;
    final napNumber = nextNap != null ? nextNap.index + 1 : null;

    aiSuggestion = AiSuggestion(
      nextNapTime: nextNap != null ? _formatHm(nextNap.start) : null,
      nextNapRationale: nextNap != null
          ? (isPt
              ? 'Soneca $napNumber de $totalNaps · dura ${_formatDurationHm(nextNap.duration)}.'
              : 'Nap $napNumber of $totalNaps · lasts ${_formatDurationHm(nextNap.duration)}.')
          : null,
      bedtimeRoutineStart: _formatHm(schedule.nightRoutineStart),
      bedtimeRationale: isPt
          ? 'Fim da última janela acordado do dia.'
          : 'End of the last wake window of the day.',
      generatedAt: DateTime.now(),
    );
    notifyListeners();

    try {
      await NotificationService.scheduleManualPlan(
        napStarts: schedule
            .upcomingNaps(now)
            .map((n) => n.start)
            .toList(growable: false),
        routineStart: schedule.nightRoutineStart,
        totalNaps: totalNaps,
        isPt: isPt,
        userName: userDisplayName,
        babyName: profile.name,
        babySex: profile.sex,
      );
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }
  }

  /// Resolves where "now" sits in the manual plan from the logged entries:
  /// the anchor timestamp, whether the baby is currently asleep, and how many
  /// naps have already finished today. Re-derived on every call so the plan
  /// re-anchors to real events as they are logged.
  ({DateTime time, bool asleep, int completedNaps}) _resolveManualAnchor() {
    final now = DateTime.now();
    if (entries.isEmpty) {
      return (time: now, asleep: false, completedNaps: 0);
    }

    // Walk the newest entries until the current night's block ends. Day naps
    // sitting above the most recent night entry are "today".
    final todayDayEntries = <SleepEntry>[];
    DateTime? morningWake;
    for (final entry in entries) {
      if (!entry.isDay) {
        morningWake = entry.wokeUp;
        break;
      }
      todayDayEntries.add(entry);
    }

    final completedNaps =
        todayDayEntries.where((e) => e.wokeUp != null).length;
    final latest = entries.first;

    // Currently asleep (day nap in progress).
    if (latest.isDay && latest.slept != null && latest.wokeUp == null) {
      return (
        time: latest.slept!,
        asleep: true,
        completedNaps: completedNaps,
      );
    }

    // Awake after a day nap.
    if (latest.isDay && latest.wokeUp != null) {
      return (
        time: latest.wokeUp!,
        asleep: false,
        completedNaps: completedNaps,
      );
    }

    // Just woke up for the day (latest entry is the night block).
    if (!latest.isDay && morningWake != null) {
      return (time: morningWake, asleep: false, completedNaps: 0);
    }

    // Fallbacks: night entry still in progress, or no usable timestamp.
    return (
      time: morningWake ?? latest.slept ?? now,
      asleep: false,
      completedNaps: completedNaps,
    );
  }

  String _formatDurationHm(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _formatMinutesOfDay(int minutesOfDay) {
    final h = (minutesOfDay ~/ 60) % 24;
    final m = minutesOfDay % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  int? _averageMinuteOfDay(Iterable<DateTime?> times) {
    final values = times
        .whereType<DateTime>()
        .map((t) => t.hour * 60 + t.minute)
        .toList();
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  /// Recent completed night entries (newest first), capped so old data doesn't
  /// dominate the averages.
  List<SleepEntry> _recentNights({int limit = 14}) {
    final nights = <SleepEntry>[];
    for (final e in entries) {
      if (!e.isDay && e.slept != null && e.wokeUp != null) {
        nights.add(e);
        if (nights.length >= limit) break;
      }
    }
    return nights;
  }

  /// The whole day laid out as alternating awake/asleep windows, computed from
  /// the manual plan and anchored at the average morning wake-up (or 06:00 when
  /// there isn't enough history). Used by the analytics "day forecast" tab when
  /// AI suggestions are disabled.
  List<SleepWindow> manualScheduleWindows() {
    final profile = babyProfile;
    if (profile == null) return const [];

    final nights = _recentNights();
    final wakeMinutes =
        _averageMinuteOfDay(nights.map((e) => e.wokeUp)) ?? 6 * 60;
    final now = DateTime.now();
    final wake = DateTime(
      now.year,
      now.month,
      now.day,
      wakeMinutes ~/ 60,
      wakeMinutes % 60,
    );

    final schedule = ManualSleepPlan.compute(
      anchorTime: wake,
      anchorIsAsleep: false,
      completedNaps: 0,
      wakeWindowsMinutes: profile.resolvedManualWakeWindowsMinutes,
      napDurationsMinutes: profile.resolvedManualNapDurationsMinutes,
    );

    final isPt = locale.languageCode == 'pt';
    final awakeLabel = isPt ? 'Acordado' : 'Awake';

    // N naps → N+1 awake windows → night sleep. There is no "extra" nap: the
    // slot after the last nap is the last wake window, and what follows is the
    // night sleep, which runs until the next day's wake-up.
    final windows = <SleepWindow>[];
    var cursor = wake;
    for (final nap in schedule.naps) {
      windows.add(SleepWindow(
        isAwake: true,
        startTime: _formatHm(cursor),
        endTime: _formatHm(nap.start),
        label: awakeLabel,
      ));
      windows.add(SleepWindow(
        isAwake: false,
        startTime: _formatHm(nap.start),
        endTime: _formatHm(nap.end),
        label: isPt ? 'Soneca ${nap.index + 1}' : 'Nap ${nap.index + 1}',
      ));
      cursor = nap.end;
    }
    // Last wake window: from the last nap (or morning wake) to the night
    // routine start.
    windows.add(SleepWindow(
      isAwake: true,
      startTime: _formatHm(cursor),
      endTime: _formatHm(schedule.nightRoutineStart),
      label: awakeLabel,
    ));
    // Night sleep: routine start → next day's (average) wake-up.
    final nextWake = wake.add(const Duration(days: 1));
    windows.add(SleepWindow(
      isAwake: false,
      startTime: _formatHm(schedule.nightRoutineStart),
      endTime: _formatHm(nextWake),
      label: isPt ? 'Sono noturno' : 'Night sleep',
      spansToNextDay: true,
    ));
    return windows;
  }

  /// One-line night summary for the same tab: average bedtime → average wake,
  /// from recent nights. Null when there isn't enough history.
  String? manualNightAverageLine({required bool isPt}) {
    final nights = _recentNights();
    if (nights.length < 2) return null;
    final bed = _averageMinuteOfDay(nights.map((e) => e.slept));
    final wake = _averageMinuteOfDay(nights.map((e) => e.wokeUp));
    if (bed == null || wake == null) return null;
    final bedStr = _formatMinutesOfDay(bed);
    final wakeStr = _formatMinutesOfDay(wake);
    return isPt
        ? 'Dorme ~$bedStr → acorda ~$wakeStr (média das noites recentes)'
        : 'Sleeps ~$bedStr → wakes ~$wakeStr (recent nights average)';
  }

  Future<void> refreshSleepWindowPredictions({bool force = false}) async {
    if (babyProfile?.useAiSuggestions == false) {
      _sleepWindowPredictions = '';
      notifyListeners();
      return;
    }
    // null == currently loading; a non-empty string == we already have a
    // result. A non-forced call still fetches when the value is an empty
    // string so the tab auto-populates the first time it's opened.
    if (_sleepWindowPredictions == null) return;
    if (!force && _sleepWindowPredictions!.isNotEmpty) return;
    
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
      // ISO 8601 format (locale-independent) so dates parse reliably
      // when the CSV is opened in spreadsheet apps or fed to other tools.
      String wokeUpStr = '';
      if (e.wokeUp != null) {
        wokeUpStr = DateFormat('yyyy-MM-dd HH:mm').format(e.wokeUp!);
      }
      String sleptStr = '';
      if (e.slept != null) {
        sleptStr = DateFormat('yyyy-MM-dd HH:mm').format(e.slept!);
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
    // Prepend UTF-8 BOM so spreadsheet apps (Excel) detect the encoding
    // correctly and accented characters (e.g. "Não") render properly.
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
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
      localEntryId: entry.localId,
      data: entry.toFirestore(),
      createdAt: DateTime.now(),
    );
    _syncQueue.add(item);
    _saveSyncQueue();
  }

  SleepEntry? _findEntryByLocalId(String? localId) {
    if (localId == null) return null;
    for (final e in entries) {
      if (e.localId == localId) return e;
    }
    return null;
  }

  /// Resolves the [SleepEntry] a queue item refers to. Prefers the stable
  /// [SyncQueueItem.localEntryId]; falls back to matching on the queued
  /// payload's `createdAt` for items persisted before localId tracking
  /// existed (e.g. an 'update' stranded offline by the old bug) — without
  /// this fallback, those old stuck items would stay unresolved forever
  /// even after being reset to 'pending'.
  SleepEntry? _resolveEntryForQueueItem(SyncQueueItem item) {
    final byLocalId = _findEntryByLocalId(item.localEntryId);
    if (byLocalId != null) return byLocalId;

    final createdAtRaw = item.data['createdAt'];
    if (createdAtRaw is! String) return null;
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;
    for (final e in entries) {
      if (e.createdAt == createdAt) return e;
    }
    return null;
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
              final entry = _resolveEntryForQueueItem(item);
              if (entry != null) {
                entry.firestoreId = docId;
              }
              item.entryId = docId;
              item.status = 'synced';
              break;

            case 'update':
              // entryId may still be empty here if this update was queued
              // before its paired 'create' finished syncing (e.g. while
              // offline). Resolve it from the live entry instead of trusting
              // the stale snapshot taken at queue time.
              final resolvedId = item.entryId.isNotEmpty
                  ? item.entryId
                  : _resolveEntryForQueueItem(item)?.firestoreId;
              if (resolvedId != null && resolvedId.isNotEmpty) {
                await FirebaseService().updateSleepEntry(
                  user.uid,
                  resolvedId,
                  item.data,
                );
                item.entryId = resolvedId;
                item.status = 'synced';
              } else {
                // Paired create hasn't resolved an ID yet — retry on the
                // next sync pass instead of getting stuck at 'syncing'.
                item.status = 'pending';
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

      // Mark entries as synced — but only once no queue item still targets
      // them, so an entry with a deferred/failed update doesn't get flagged
      // "synced" while its latest edit hasn't actually reached Firestore.
      for (var entry in entries.where((e) => e.syncStatus == 'pending')) {
        final stillQueued = _syncQueue.any(
          (i) =>
              i.status != 'synced' &&
              (i.localEntryId == entry.localId ||
                  (entry.firestoreId != null &&
                      i.entryId == entry.firestoreId)),
        );
        if (stillQueued) continue;
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

        // 'syncing' is only ever meant to be a transient in-memory marker
        // while a sync attempt is in flight. Finding it on a freshly loaded
        // queue means a previous attempt was interrupted (app killed) or —
        // before this fix — an 'update' that got permanently stranded
        // because its entryId was still empty when it was processed. Reset
        // it to 'pending' so it's retried instead of abandoned forever;
        // this is what lets a previously-lost "Acordou" edit finally reach
        // Firestore once connectivity is back.
        int healedCount = 0;
        for (final item in _syncQueue) {
          if (item.status == 'syncing') {
            item.status = 'pending';
            healedCount++;
          }
        }
        if (healedCount > 0) {
          debugPrint('Recovered $healedCount stuck sync queue item(s).');
          await _saveSyncQueue();
        }
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

  // ─── Local read cache (entries + baby profile) ────────────────────────────
  // Firestore remains the source of truth, but on every cold start we'd
  // otherwise have to wait for the full entries history to download before
  // showing anything — this gets slower the more records a baby accumulates.
  // Caching the last-known data locally lets the UI render instantly from
  // disk while a fresh copy is fetched from Firestore in the background.

  Future<void> _saveEntriesCache(String uid, List<SleepEntry> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(
        list
            .map((e) => {'firestoreId': e.firestoreId, ...e.toJson()})
            .toList(),
      );
      await prefs.setString('entries_cache_$uid', json);
    } catch (e) {
      debugPrint('Error saving entries cache: $e');
    }
  }

  Future<List<SleepEntry>?> _loadEntriesCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('entries_cache_$uid');
      if (json == null) return null;
      final List<dynamic> list = jsonDecode(json);
      return list
          .map((e) => SleepEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error loading entries cache: $e');
      return null;
    }
  }

  Future<void> _saveBabyProfileCache(String uid, BabyProfile? profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (profile == null) {
        await prefs.remove('baby_profile_cache_$uid');
        return;
      }
      await prefs.setString(
        'baby_profile_cache_$uid',
        jsonEncode(profile.toFirestore()),
      );
    } catch (e) {
      debugPrint('Error saving baby profile cache: $e');
    }
  }

  Future<BabyProfile?> _loadBabyProfileCache(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('baby_profile_cache_$uid');
      if (json == null) return null;
      return BabyProfile.fromFirestore(
        Map<String, dynamic>.from(jsonDecode(json)),
      );
    } catch (e) {
      debugPrint('Error loading baby profile cache: $e');
      return null;
    }
  }

  Future<void> _migrateOldEntriesToFirestore() async {
    if (_isMigratingData) return;

    try {
      final user = FirebaseService().currentUser;
      if (user == null) return;

      // Check if already migrated
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('entries_migrated_${user.uid}') ?? false) return;

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

}
