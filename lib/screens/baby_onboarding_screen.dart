import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/baby_profile.dart';
import '../providers/app_provider.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class BabyOnboardingScreen extends StatefulWidget {
  final bool isEditing;
  const BabyOnboardingScreen({super.key, this.isEditing = false});

  @override
  State<BabyOnboardingScreen> createState() => _BabyOnboardingScreenState();
}

class _BabyOnboardingScreenState extends State<BabyOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _nameCtrl = TextEditingController();
  final _routineCtrl = TextEditingController(text: '30');

  DateTime? _birthdate;
  String _sex = 'male';
  String _feedingType = 'breast';
  bool _complementaryFood = false;
  int? _targetBedtimeHour;
  int? _targetBedtimeMinute;

  bool get _isPt => Localizations.localeOf(context).languageCode == 'pt';
  String _t(String pt, String en) => _isPt ? pt : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _populate());
  }

  void _populate() {
    final p = Provider.of<AppProvider>(context, listen: false).babyProfile;
    if (p != null) {
      setState(() {
        _nameCtrl.text = p.name ?? '';
        _birthdate = p.birthdate;
        _sex = p.sex;
        _feedingType = p.feedingType;
        _complementaryFood = p.complementaryFoodStarted;
        _routineCtrl.text = p.nightRoutineMinutes.toString();
        _targetBedtimeHour = p.targetBedtimeHour;
        _targetBedtimeMinute = p.targetBedtimeMinute;
      });
      return;
    }

    // New user: prefill baby name captured during registration.
    _prefillBabyNameFromUserProfile();
  }

  Future<void> _prefillBabyNameFromUserProfile() async {
    final user = FirebaseService().currentUser;
    if (user == null) return;
    final profile = await FirebaseService().getUserProfile(user.uid);
    final pendingBabyName = (profile['pendingBabyName'] as String?)?.trim();
    if (!mounted || pendingBabyName == null || pendingBabyName.isEmpty) return;
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() {
        _nameCtrl.text = pendingBabyName;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _routineCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? now.subtract(const Duration(days: 90)),
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthdate = picked);
  }

  Future<void> _pickBedtime() async {
    final init = (_targetBedtimeHour != null && _targetBedtimeMinute != null)
        ? TimeOfDay(hour: _targetBedtimeHour!, minute: _targetBedtimeMinute!)
        : const TimeOfDay(hour: 19, minute: 30);
    final picked = await showTimePicker(
      context: context,
      initialTime: init,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _targetBedtimeHour = picked.hour;
        _targetBedtimeMinute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
          'Informe a data de nascimento.',
          'Please enter the birth date.',
        )),
      ));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
          'Informe o nome do bebê.',
          'Please enter the baby name.',
        )),
      ));
      return;
    }

    setState(() => _isSaving = true);

    // Request notification permissions when saving profile (first time)
    try {
      await NotificationService.initialize();
      await NotificationService.requestPermissions();
    } catch (_) {}

    final profile = BabyProfile(
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      birthdate: _birthdate,
      sex: _sex,
      feedingType: _feedingType,
      complementaryFoodStarted: _complementaryFood,
      nightRoutineMinutes: int.tryParse(_routineCtrl.text.trim()) ?? 30,
      targetBedtimeHour: _targetBedtimeHour,
      targetBedtimeMinute: _targetBedtimeMinute,
    );

    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.saveBabyProfile(profile);
    final user = FirebaseService().currentUser;
    if (user != null) {
      try {
        await FirebaseService().clearPendingBabyName(user.uid);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (widget.isEditing) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('Perfil salvo!', 'Profile saved!')),
      ));
      provider.refreshAiSuggestions();
    }
    // If first-time onboarding: AuthGate reacts to babyProfile becoming non-null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF100818), Color(0xFF1B1030), Color(0xFF0D0715)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (widget.isEditing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Color(0xFFF7F2FF)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        _t('Perfil do Bebê', 'Baby Profile'),
                        style: const TextStyle(
                          color: Color(0xFFF7F2FF),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!widget.isEditing) ...[
                            const SizedBox(height: 12),
                            Text(
                              _t('Bem-vindo ao Dante Sleep! 👋',
                                  'Welcome to Dante Sleep! 👋'),
                              style: const TextStyle(
                                color: Color(0xFFF7F2FF),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _t(
                                'Nos conte sobre seu bebê para ativar as sugestões de IA.',
                                'Tell us about your baby to enable AI suggestions.',
                              ),
                              style: const TextStyle(
                                  color: Color(0xFFB8A7D5), fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                          ],

                          _label(_t('Nome do bebê *', 'Baby name *')),
                          _field(
                            controller: _nameCtrl,
                            hint: 'Dante',
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) {
                                return _t('Campo obrigatório', 'Required field');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _label(_t('Data de nascimento *', 'Birth date *')),
                          _dateTile(
                            value: _birthdate != null
                                ? DateFormat('dd/MM/yyyy').format(_birthdate!)
                                : _t('Selecionar', 'Select'),
                            onTap: _pickBirthdate,
                          ),
                          const SizedBox(height: 20),

                          _label(_t('Sexo', 'Sex')),
                          _segmented(
                            options: [
                              ('male', _t('Menino', 'Boy'),
                                  Icons.boy_outlined),
                              ('female', _t('Menina', 'Girl'),
                                  Icons.girl_outlined),
                            ],
                            selected: _sex,
                            onSelect: (v) => setState(() => _sex = v),
                          ),
                          const SizedBox(height: 20),

                          _label(_t('Alimentação', 'Feeding')),
                          _segmented(
                            options: [
                              ('breast', _t('Peito', 'Breast'),
                                  Icons.child_care_outlined),
                              ('formula', _t('Fórmula', 'Formula'),
                                  Icons.science_outlined),
                              ('mixed', _t('Misto', 'Mixed'),
                                  Icons.swap_horiz_outlined),
                            ],
                            selected: _feedingType,
                            onSelect: (v) => setState(() => _feedingType = v),
                          ),
                          const SizedBox(height: 16),

                          _switchTile(
                            label: _t('Alimentação complementar iniciada?',
                                'Complementary food started?'),
                            subtitle: _t('Papinhas, BLW, purês…',
                                'Purees, BLW, soft foods…'),
                            value: _complementaryFood,
                            onChanged: (v) =>
                                setState(() => _complementaryFood = v),
                          ),
                          const SizedBox(height: 20),

                          _label(_t('Duração da rotina noturna (min)',
                              'Night routine duration (min)')),
                          _field(
                            controller: _routineCtrl,
                            hint: '30',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 5 || n > 180) {
                                return _t(
                                    'Entre 5 e 180', 'Between 5 and 180');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _label(_t('Horário alvo de dormir',
                              'Target bedtime')),
                          _dateTile(
                            icon: Icons.bedtime_outlined,
                            value: (_targetBedtimeHour != null &&
                                    _targetBedtimeMinute != null)
                                ? '${_targetBedtimeHour.toString().padLeft(2, '0')}:${_targetBedtimeMinute.toString().padLeft(2, '0')}'
                                : _t('Selecionar', 'Select'),
                            onTap: _pickBedtime,
                          ),
                          const SizedBox(height: 20),

                          const SizedBox(height: 32),

                          ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A2A72),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _t('Salvar Perfil', 'Save Profile'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFB8A7D5),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );

  Widget _field({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? helperText,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Color(0xFFF7F2FF)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6A5580)),
          helperText: helperText,
          helperStyle:
              const TextStyle(color: Color(0xFF7A6990), fontSize: 12),
          helperMaxLines: 2,
          filled: true,
          fillColor: const Color(0xFF1A1226),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        validator: validator,
      );

  Widget _dateTile({
    required String value,
    required VoidCallback onTap,
    IconData icon = Icons.calendar_today_outlined,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1226),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF9A7CFF), size: 20),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  color:
                      (value == 'Selecionar' || value == 'Select')
                          ? const Color(0xFF6A5580)
                          : const Color(0xFFF7F2FF),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _segmented({
    required List<(String, String, IconData)> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) =>
      Row(
        children: options.map((opt) {
          final sel = opt.$1 == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      sel ? const Color(0xFF4A2A72) : const Color(0xFF1A1226),
                  borderRadius: BorderRadius.circular(12),
                  border: sel
                      ? Border.all(color: const Color(0xFF9A7CFF), width: 1.5)
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(opt.$3,
                        color: sel
                            ? const Color(0xFFEADFFF)
                            : const Color(0xFF6A5580),
                        size: 22),
                    const SizedBox(height: 4),
                    Text(
                      opt.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFFEADFFF)
                            : const Color(0xFF6A5580),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _switchTile({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1226),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          title: Text(label,
              style:
                  const TextStyle(color: Color(0xFFF7F2FF), fontSize: 14)),
          subtitle: Text(subtitle,
              style:
                  const TextStyle(color: Color(0xFF7A6990), fontSize: 12)),
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF9A7CFF),
        ),
      );
}
