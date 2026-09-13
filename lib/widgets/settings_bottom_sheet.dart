import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../knowledge/manual_sleep_plan.dart';
import '../l10n/localized_strings.dart';
import '../models/baby_profile.dart';
import '../providers/app_provider.dart';
import '../screens/baby_onboarding_screen.dart';
import '../screens/link_email_password_screen.dart';
import '../services/firebase_service.dart';

class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  String? _displayName;
  String? _photoBase64;
  bool _isLoading = true;
  bool _hasGoogleProvider = false;
  bool _hasPasswordProvider = false;
  bool _isLinkingGoogle = false;

  // ─── Manual sleep plan editing state ──────────────────────────────────────
  bool _manualSeeded = false;
  int _napsPerDay = 3;
  bool _sameWakeWindow = true;
  bool _sameNapDuration = true;
  final List<TextEditingController> _wakeWindowCtrls = [];
  final List<TextEditingController> _napDurationCtrls = [];

  static final _hmRegex = RegExp(r'^\s*([0-9]{1,2}):([0-5][0-9])\s*$');

  bool get _isPt =>
      Localizations.localeOf(context).languageCode == 'pt';
  String _t(String pt, String en) => _isPt ? pt : en;

  static String _minutesToHm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  static int? _hmToMinutes(String text) {
    final match = _hmRegex.firstMatch(text);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_manualSeeded) {
      final profile =
          Provider.of<AppProvider>(context, listen: false).babyProfile;
      if (profile != null) {
        _seedManualState(profile);
        _manualSeeded = true;
      }
    }
  }

  void _seedManualState(BabyProfile profile) {
    _napsPerDay = profile.manualNapsPerDay;
    _sameWakeWindow = profile.manualSameWakeWindow;
    _sameNapDuration = profile.manualSameNapDuration;
    final ww = _sameWakeWindow
        ? [
            profile.manualWakeWindowsMinutes.isEmpty
                ? 150
                : profile.manualWakeWindowsMinutes.first
          ]
        : profile.resolvedManualWakeWindowsMinutes;
    final nd = _sameNapDuration
        ? [
            profile.manualNapDurationsMinutes.isEmpty
                ? 90
                : profile.manualNapDurationsMinutes.first
          ]
        : profile.resolvedManualNapDurationsMinutes;
    _rebuildCtrls(_wakeWindowCtrls, ww);
    _rebuildCtrls(_napDurationCtrls, nd);
  }

  void _rebuildCtrls(List<TextEditingController> target, List<int> minutes) {
    for (final c in target) {
      c.dispose();
    }
    target
      ..clear()
      ..addAll(minutes.map((m) => TextEditingController(text: _minutesToHm(m))));
  }

  /// Resizes a controller list to [count], keeping existing text and filling
  /// new slots with the last known value (or a fallback).
  void _resizeCtrls(
    List<TextEditingController> target,
    int count,
    int fallbackMinutes,
  ) {
    while (target.length > count) {
      target.removeLast().dispose();
    }
    while (target.length < count) {
      final seed = target.isNotEmpty
          ? target.last.text
          : _minutesToHm(fallbackMinutes);
      target.add(TextEditingController(text: seed));
    }
  }

  void _syncCtrlCounts() {
    _resizeCtrls(_wakeWindowCtrls, _sameWakeWindow ? 1 : _napsPerDay + 1, 150);
    _resizeCtrls(_napDurationCtrls, _sameNapDuration ? 1 : _napsPerDay, 90);
  }

  List<int> _readMinutes(List<TextEditingController> ctrls, int fallback) =>
      ctrls
          .map((c) => _hmToMinutes(c.text) ?? fallback)
          .toList(growable: false);

  @override
  void dispose() {
    for (final c in _wakeWindowCtrls) {
      c.dispose();
    }
    for (final c in _napDurationCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseService().currentUser;
    if (user != null) {
      final profile = await FirebaseService().getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _displayName = profile['displayName'] ?? user.displayName ?? user.email;
          _photoBase64 = profile['photoBase64'];
          _hasGoogleProvider = FirebaseService().hasGoogleProvider;
          _hasPasswordProvider = FirebaseService().hasPasswordProvider;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _linkGoogleAccount(LocalizedStrings strings) async {
    setState(() => _isLinkingGoogle = true);
    try {
      final user = await FirebaseService().linkGoogleAccount();
      if (!mounted) return;
      if (user != null) {
        setState(() => _hasGoogleProvider = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.linkGoogleSuccess)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final String message;
      switch (e.code) {
        case 'credential-already-in-use':
        case 'email-already-in-use':
        case 'provider-already-linked':
          message = strings.linkErrorEmailInUse;
          break;
        case 'requires-recent-login':
          message = strings.linkErrorRequiresRecentLogin;
          break;
        default:
          message = strings.linkErrorGeneric;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.linkErrorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _isLinkingGoogle = false);
    }
  }

  Future<void> _openLinkEmailPasswordScreen() async {
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LinkEmailPasswordScreen()),
    );
    if (linked == true && mounted) {
      setState(() => _hasPasswordProvider = true);
    }
  }

  Future<void> _updateDisplayName(String newName) async {
    final user = FirebaseService().currentUser;
    if (user != null) {
      await FirebaseService().updateUserProfile(user.uid, {'displayName': newName});
      if (mounted) {
        setState(() {
          _displayName = newName;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      
      final user = FirebaseService().currentUser;
      if (user != null) {
        await FirebaseService().updateUserProfile(user.uid, {'photoBase64': base64Str});
        if (mounted) {
          setState(() {
            _photoBase64 = base64Str;
          });
        }
      }
    }
  }

  void _showEditNameDialog(BuildContext context, LocalizedStrings strings) {
    final TextEditingController controller = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.editNameTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: strings.nameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _updateDisplayName(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  List<int> _expand(List<int> src, int length, int fallback) {
    if (length <= 0) return const [];
    final base = src.isEmpty ? [fallback] : src;
    return List<int>.generate(
      length,
      (i) => i < base.length ? base[i] : base.last,
    );
  }

  List<int> get _resolvedWakeWindows => _expand(
        _readMinutes(_wakeWindowCtrls, 150),
        _napsPerDay + 1,
        150,
      );

  List<int> get _resolvedNapDurations => _expand(
        _readMinutes(_napDurationCtrls, 90),
        _napsPerDay,
        90,
      );

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _previewText() {
    final now = DateTime.now();
    final anchor = DateTime(now.year, now.month, now.day, 6, 0);
    final schedule = ManualSleepPlan.compute(
      anchorTime: anchor,
      anchorIsAsleep: false,
      completedNaps: 0,
      wakeWindowsMinutes: _resolvedWakeWindows,
      napDurationsMinutes: _resolvedNapDurations,
    );
    final naps = schedule.naps
        .map((n) => '${_fmtClock(n.start)}–${_fmtClock(n.end)}')
        .join(' · ');
    final routine =
        '${_t('ritual', 'routine')} ${_fmtClock(schedule.nightRoutineStart)}';
    return naps.isEmpty ? routine : '$naps · $routine';
  }

  Future<void> _saveManualPlan(AppProvider provider) async {
    final valid = _wakeWindowCtrls.every((c) => _hmToMinutes(c.text) != null) &&
        _napDurationCtrls.every((c) => _hmToMinutes(c.text) != null);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
          'Use o formato h:mm (ex: 2:30) em todos os campos.',
          'Use the h:mm format (e.g. 2:30) in every field.',
        )),
      ));
      return;
    }
    await provider.setManualSleepPlan(
      napsPerDay: _napsPerDay,
      sameWakeWindow: _sameWakeWindow,
      sameNapDuration: _sameNapDuration,
      wakeWindowsMinutes: _readMinutes(_wakeWindowCtrls, 150),
      napDurationsMinutes: _readMinutes(_napDurationCtrls, 90),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Agenda de sono salva!', 'Sleep schedule saved!')),
      ));
    }
  }

  Widget _buildAiSection(
    AppProvider provider,
    bool isDay,
    Color textColor,
    Color bgColor,
  ) {
    final profile = provider.babyProfile;
    final subtitleColor =
        isDay ? const Color(0xFF4B6287) : const Color(0xFFB8A7D5);
    final useAi = profile?.useAiSuggestions ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          secondary: Icon(Icons.auto_awesome, color: textColor),
          title: Text(
            _t('Usar sugestões de IA', 'Use AI suggestions'),
            style: TextStyle(color: textColor),
          ),
          subtitle: Text(
            profile == null
                ? _t('Complete o perfil do bebê primeiro.',
                    'Complete the baby profile first.')
                : (useAi
                    ? _t('A IA calcula sonecas, rotina noturna e previsões.',
                        'AI computes naps, bedtime routine and forecasts.')
                    : _t('O app calcula a agenda pelas janelas abaixo.',
                        'The app computes the schedule from the windows below.')),
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
          value: useAi,
          activeThumbColor: const Color(0xFF9A7CFF),
          onChanged: profile == null
              ? null
              : (v) => provider.setUseAiSuggestions(v),
        ),
        if (profile != null && !useAi)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildManualPlanEditor(
              provider,
              isDay,
              textColor,
              subtitleColor,
              bgColor,
            ),
          ),
      ],
    );
  }

  Widget _buildManualPlanEditor(
    AppProvider provider,
    bool isDay,
    Color textColor,
    Color subtitleColor,
    Color bgColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Naps per day stepper
        Row(
          children: [
            Expanded(
              child: Text(
                _t('Sonecas por dia', 'Naps per day'),
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
            _stepperButton(Icons.remove, textColor, () {
              if (_napsPerDay > 0) {
                setState(() {
                  _napsPerDay--;
                  _syncCtrlCounts();
                });
              }
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$_napsPerDay',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _stepperButton(Icons.add, textColor, () {
              if (_napsPerDay < 6) {
                setState(() {
                  _napsPerDay++;
                  _syncCtrlCounts();
                });
              }
            }),
          ],
        ),
        const SizedBox(height: 8),

        // Wake windows
        _sameToggleRow(
          label: _t('Mesma janela acordado para todas',
              'Same wake window for all'),
          value: _sameWakeWindow,
          textColor: textColor,
          subtitleColor: subtitleColor,
          onChanged: (v) => setState(() {
            _sameWakeWindow = v;
            _syncCtrlCounts();
          }),
        ),
        ..._buildHmFields(
          ctrls: _wakeWindowCtrls,
          single: _sameWakeWindow,
          singleLabel: _t('Janela acordado', 'Wake window'),
          indexedLabel: (i) => i == _napsPerDay
              ? _t('Acordado → noite', 'Awake → night')
              : _t('Acordado ${i + 1}', 'Awake ${i + 1}'),
          textColor: textColor,
          subtitleColor: subtitleColor,
          bgColor: bgColor,
          isDay: isDay,
        ),
        const SizedBox(height: 10),

        // Nap durations
        _sameToggleRow(
          label: _t('Mesma duração de soneca para todas',
              'Same nap duration for all'),
          value: _sameNapDuration,
          textColor: textColor,
          subtitleColor: subtitleColor,
          onChanged: (v) => setState(() {
            _sameNapDuration = v;
            _syncCtrlCounts();
          }),
        ),
        ..._buildHmFields(
          ctrls: _napDurationCtrls,
          single: _sameNapDuration,
          singleLabel: _t('Duração da soneca', 'Nap duration'),
          indexedLabel: (i) => _t('Soneca ${i + 1}', 'Nap ${i + 1}'),
          textColor: textColor,
          subtitleColor: subtitleColor,
          bgColor: bgColor,
          isDay: isDay,
        ),
        const SizedBox(height: 12),

        // Live preview
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDay ? const Color(0xFFECF4FF) : const Color(0xFF2A1B3E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('Prévia (acordar 06:00)', 'Preview (wake 06:00)'),
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _previewText(),
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => _saveManualPlan(provider),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A2A72),
              foregroundColor: Colors.white,
            ),
            child: Text(_t('Salvar agenda', 'Save schedule')),
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      );

  Widget _sameToggleRow({
    required String label,
    required bool value,
    required Color textColor,
    required Color subtitleColor,
    required ValueChanged<bool> onChanged,
  }) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: const Color(0xFF9A7CFF),
            visualDensity: VisualDensity.compact,
          ),
        ],
      );

  List<Widget> _buildHmFields({
    required List<TextEditingController> ctrls,
    required bool single,
    required String singleLabel,
    required String Function(int) indexedLabel,
    required Color textColor,
    required Color subtitleColor,
    required Color bgColor,
    required bool isDay,
  }) {
    Widget field(TextEditingController c, String label) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ),
              SizedBox(
                width: 84,
                child: TextField(
                  controller: c,
                  keyboardType: TextInputType.datetime,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'h:mm',
                    hintStyle: TextStyle(color: subtitleColor),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: isDay
                        ? const Color(0xFFECF4FF)
                        : const Color(0xFF2A1B3E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    if (single) {
      final c = ctrls.isNotEmpty
          ? ctrls.first
          : (ctrls..add(TextEditingController(text: '2:30'))).first;
      return [field(c, singleLabel)];
    }
    return [
      for (var i = 0; i < ctrls.length; i++) field(ctrls[i], indexedLabel(i)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final strings = LocalizedStrings(context);
    final isDay = provider.isVisualDay;
    final textColor = isDay ? const Color(0xFF12233F) : const Color(0xFFF2ECFF);
    final bgColor = isDay ? Colors.white : const Color(0xFF1D1130);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Profile Header
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: isDay ? Colors.grey[200] : Colors.grey[800],
                              backgroundImage: _photoBase64 != null
                                  ? MemoryImage(base64Decode(_photoBase64!))
                                  : null,
                              child: _photoBase64 == null
                                  ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2A6CE8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayName ?? strings.userDefaultName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showEditNameDialog(context, strings),
                                  icon: Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: isDay
                                        ? const Color(0xFF2A6CE8)
                                        : const Color(0xFFA5C5FF),
                                  ),
                                  tooltip: strings.editName,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // Account linking (email <-> Google)
              if (_hasPasswordProvider && !_hasGoogleProvider) ...[
                ListTile(
                  leading: Icon(Icons.link, color: textColor),
                  title: Text(
                    strings.settingsLinkGoogleTitle,
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    strings.settingsLinkGoogleSubtitle,
                    style: TextStyle(
                      color: isDay
                          ? const Color(0xFF4B6287)
                          : const Color(0xFFB8A7D5),
                      fontSize: 12,
                    ),
                  ),
                  trailing: _isLinkingGoogle
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _isLinkingGoogle
                      ? null
                      : () => _linkGoogleAccount(strings),
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              ] else if (_hasGoogleProvider && !_hasPasswordProvider) ...[
                ListTile(
                  leading: Icon(Icons.password, color: textColor),
                  title: Text(
                    strings.settingsAddEmailPasswordTitle,
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    strings.settingsAddEmailPasswordSubtitle,
                    style: TextStyle(
                      color: isDay
                          ? const Color(0xFF4B6287)
                          : const Color(0xFFB8A7D5),
                      fontSize: 12,
                    ),
                  ),
                  onTap: _openLinkEmailPasswordScreen,
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              ],

              // Baby Profile
              ListTile(
                leading: Icon(Icons.child_care, color: textColor),
                title: Text(
                  strings.babyProfile,
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BabyOnboardingScreen(isEditing: true),
                    ),
                  );
                },
              ),

              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // AI suggestions toggle + manual sleep plan
              _buildAiSection(provider, isDay, textColor, bgColor),

              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

              // Import/Export CSV
              /*
              ListTile(
                leading: Icon(Icons.download_rounded, color: textColor),
                title: Text(strings.importCsv, style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context); // Close sheet before action
                  final result = await provider.importCsv();
                  if (context.mounted && result != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.getEntriesImportedMessage(result))),
                    );
                  } else if (context.mounted && result == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.importCancelledOrFailed)),
                    );
                  }
                },
              ),
              */
              ListTile(
                leading: Icon(Icons.upload_rounded, color: textColor),
                title: Text(strings.exportCsv, style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.pop(context);
                  final filename = await provider.exportCsv(
                    headers: strings.getCsvHeaders(),
                    dayValue: strings.dayLabel,
                    nightValue: strings.nightLabel,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.getCsvExportedMessage(filename))),
                    );
                  }
                },
              ),
              
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              
              // Language Select
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.language, color: textColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(strings.language, style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                    DropdownButton<String>(
                      value: provider.locale.languageCode,
                      dropdownColor: bgColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: textColor),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.setLanguage(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'pt',
                          child: Row(
                            children: [
                              const Text('🇧🇷', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(strings.portuguese, style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(
                            children: [
                              const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(strings.english, style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Visual Theme Select
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, color: textColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(strings.forceVisualTheme, style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                    DropdownButton<String>(
                      value: provider.visualThemeMode,
                      dropdownColor: bgColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: textColor),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.setVisualThemeMode(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'auto',
                          child: Text(strings.visualThemeAuto, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'day',
                          child: Text(strings.visualThemeDay, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: 'night',
                          child: Text(strings.visualThemeNight, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time Format Select
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: textColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(strings.timeFormat, style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                    DropdownButton<bool>(
                      value: provider.is24Hour,
                      dropdownColor: bgColor,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, color: textColor),
                      onChanged: (bool? newValue) {
                        if (newValue != null) {
                          provider.set24Hour(newValue);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: false,
                          child: Text(strings.hourFormat12, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text(strings.hourFormat24, style: TextStyle(color: textColor, fontSize: 14)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
              
              // Logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(strings.logout, style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  provider.clearUserData();
                  await FirebaseService().signOut();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
