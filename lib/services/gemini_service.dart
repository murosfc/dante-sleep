import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';

class NvidiaService {
  NvidiaService._();

  static const _invokeUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  static Future<AiSuggestion?> getSuggestions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    final modelsToTry = <String>[
      if (preferredModel != null && preferredModel.trim().isNotEmpty)
        preferredModel.trim(),
      'meta/llama-4-maverick-17b-128e-instruct',
      'meta/llama-3.1-70b-instruct',
    ].toSet().toList();

    try {
      final isPt = languageCode == 'pt';
      final prompt = _buildPrompt(
        profile: profile,
        entries: entries,
        isPt: isPt,
      );

      Object? lastError;
      for (final modelName in modelsToTry) {
        try {
          final response = await http
              .post(
                Uri.parse(_invokeUrl),
                headers: {
                  'Authorization': 'Bearer ${apiKey.trim()}',
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'model': modelName,
                  'messages': [
                    {'role': 'user', 'content': prompt},
                  ],
                  'max_tokens': 512,
                  'temperature': 0.3,
                  'top_p': 1.0,
                  'frequency_penalty': 0.0,
                  'presence_penalty': 0.0,
                  'stream': false,
                }),
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode >= 400) {
            final body = response.body;
            if (_isModelNotSupportedError(body)) {
              lastError = body;
              continue;
            }
            throw HttpException(
              'NVIDIA API error ${response.statusCode}: $body',
            );
          }

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) {
            throw const FormatException('Invalid NVIDIA response: no choices');
          }

          final first = choices.first;
          if (first is! Map<String, dynamic>) {
            throw const FormatException('Invalid NVIDIA response: bad choice');
          }

          final message = first['message'];
          if (message is! Map<String, dynamic>) {
            throw const FormatException('Invalid NVIDIA response: no message');
          }

          final text = (message['content'] as String?) ?? '';
          return _parseResponse(text, isPt: isPt);
        } catch (e) {
          lastError = e;
          if (!_isModelNotSupportedError(e.toString())) {
            debugPrint('NvidiaService error ($modelName): $e');
            return AiSuggestion(error: e.toString());
          }
        }
      }

      final message = lastError?.toString() ??
          'No compatible NVIDIA model found for this API key/project.';
      debugPrint('NvidiaService model fallback error: $message');
      return AiSuggestion(error: message);
    } catch (e) {
      debugPrint('NvidiaService error: $e');
      return AiSuggestion(error: e.toString());
    }
  }

  static bool _isModelNotSupportedError(String message) {
    final m = message.toLowerCase();
    return m.contains('not found') ||
        m.contains('not supported') ||
      m.contains('invalid model') ||
      m.contains('unknown model') ||
        m.contains('unsupported');
  }

  static String _buildPrompt({
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required bool isPt,
  }) {
    final rag = SleepKnowledgeBase.getContext(profile.birthdate, isPt: isPt);
    final babyName = profile.name?.isNotEmpty == true
      ? profile.name!
      : (isPt
        ? (profile.sex == 'female' ? 'sua bebê' : 'seu bebê')
        : 'your baby');
    final ageStr = profile.getAgeString(isPt: isPt);
    final sexStr = isPt
        ? (profile.sex == 'male' ? 'Masculino' : 'Feminino')
        : (profile.sex == 'male' ? 'Male' : 'Female');
    final feedingStr = profile.getFeedingLabel(isPt: isPt);
    final complementaryStr = isPt
        ? (profile.complementaryFoodStarted ? 'Sim' : 'Não')
        : (profile.complementaryFoodStarted ? 'Yes' : 'No');
    final targetBed = profile.targetBedtimeString;
    final routineMin = profile.nightRoutineMinutes;
    final history = _formatHistory(entries, isPt: isPt);
    final currentContext = _currentSleepContext(entries, isPt: isPt);
    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    if (isPt) {
      return '''Você é um especialista em sono infantil baseado em evidências. Forneça sugestões práticas e precisas.

HORÁRIO ATUAL: $nowStr

PERFIL DO BEBÊ:
- Nome: $babyName  Idade: $ageStr  Sexo: $sexStr
- Alimentação: $feedingStr
- Alimentação complementar iniciada: $complementaryStr
- Duração da rotina noturna: $routineMin minutos
- Horário alvo de dormir: $targetBed

DIRETRIZES PARA A FAIXA ETÁRIA:
$rag

HISTÓRICO RECENTE (mais recente primeiro):
$history

CONTEXTO ATUAL:
$currentContext

Determine:
1. Se for período DIURNO: horário ideal da PRÓXIMA SONECA (use janela de vigília/tempo acordado desde o último acordar)
2. Se for fim da tarde e faltar no máximo 90 min para a rotina noturna: você PODE sugerir soneca ponte curta
3. Soneca ponte NUNCA deve ser sugerida de manhã
4. Se for período NOTURNO: NÃO usar janela de vigília para mamadas noturnas; apenas prever o horário final de acordar de manhã
5. Horário para INICIAR A ROTINA NOTURNA (considere $routineMin min de rotina para dormir às $targetBed), somente quando fizer sentido no período diurno

IMPORTANTE DE IDIOMA:
- Responda em português do Brasil
- Não use termos em inglês como "wake time" ou "wake window"; use "tempo acordado" ou "janela de vigília"

RESPONDA APENAS com JSON válido, sem texto adicional:
{"nextNapTime":"HH:mm|null","nextNapRationale":"1 frase explicando","bedtimeRoutineStart":"HH:mm|null","bedtimeRationale":"1 frase explicando","nightWakeTime":"HH:mm|null","nightWakeRationale":"1 frase explicando"}''';
    } else {
      return '''You are an evidence-based pediatric sleep expert. Provide precise, practical suggestions.

CURRENT TIME: $nowStr

BABY PROFILE:
- Name: $babyName  Age: $ageStr  Sex: $sexStr
- Feeding: $feedingStr
- Complementary food started: $complementaryStr
- Night routine duration: $routineMin minutes
- Target bedtime: $targetBed

GUIDELINES FOR AGE RANGE:
$rag

RECENT HISTORY (newest first):
$history

CURRENT CONTEXT:
$currentContext

Determine:
1. If it's DAYTIME: ideal time for the NEXT NAP (use age-appropriate wake window since last wake-up)
2. A bridge nap is allowed only near bedtime (up to 90 minutes before the bedtime routine)
3. Never suggest a bridge nap in the morning
4. If it's NIGHTTIME: do not apply wake windows to feed-and-back-to-sleep events; only estimate final morning wake-up
5. Time to START THE NIGHT ROUTINE ($routineMin min routine to sleep at $targetBed), only when it is applicable during daytime

RESPOND ONLY with valid JSON, no additional text:
{"nextNapTime":"HH:mm|null","nextNapRationale":"1 sentence explanation","bedtimeRoutineStart":"HH:mm|null","bedtimeRationale":"1 sentence explanation","nightWakeTime":"HH:mm|null","nightWakeRationale":"1 sentence explanation"}''';
    }
  }

  static String _currentSleepContext(List<SleepEntry> entries, {required bool isPt}) {
    if (entries.isEmpty) {
      return isPt
          ? 'Sem registros suficientes para detectar contexto de dia/noite.'
          : 'Not enough records to infer day/night context.';
    }

    final latest = entries.first;
    final latestPeriod = latest.isDay ? (isPt ? 'dia' : 'day') : (isPt ? 'noite' : 'night');
    final currentlySleeping = latest.slept != null && latest.wokeUp == null;
    final sleepingText = currentlySleeping
        ? (isPt ? 'sim' : 'yes')
        : (isPt ? 'não' : 'no');

    return isPt
        ? 'Último período registrado: $latestPeriod. Dormindo agora: $sleepingText.'
        : 'Last recorded period: $latestPeriod. Currently sleeping: $sleepingText.';
  }

  static String _formatHistory(List<SleepEntry> entries, {required bool isPt}) {
    if (entries.isEmpty) {
      return isPt ? 'Nenhum registro ainda.' : 'No records yet.';
    }
    final recent = entries.take(7).toList();
    final buf = StringBuffer();
    for (final e in recent) {
      final slept = e.slept != null ? _fmt(e.slept!) : '--:--';
      final woke = e.wokeUp != null ? _fmt(e.wokeUp!) : '--:--';
      final dur = (e.slept != null && e.wokeUp != null)
          ? '${e.wokeUp!.difference(e.slept!).inHours}h${(e.wokeUp!.difference(e.slept!).inMinutes % 60).toString().padLeft(2, '0')}m'
          : '?';
      final period = e.isDay
          ? (isPt ? 'soneca' : 'nap')
          : (isPt ? 'noite' : 'night');
      buf.writeln(
        isPt
            ? '- Dormiu $slept → Acordou $woke ($dur) [$period]'
            : '- Slept $slept → Woke $woke ($dur) [$period]',
      );
    }
    return buf.toString().trimRight();
  }

  static String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static AiSuggestion _parseResponse(String raw, {required bool isPt}) {
    String cleaned = raw.trim();
    // Strip markdown code fences
    cleaned = cleaned.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();

    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd <= jsonStart) {
      return const AiSuggestion(error: 'Could not parse AI response');
    }

    try {
      final map = jsonDecode(cleaned.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;
      final nextNapRationale = _normalizeRationale(
        map['nextNapRationale'] as String?,
        isPt: isPt,
      );
      final bedtimeRationale = _normalizeRationale(
        map['bedtimeRationale'] as String?,
        isPt: isPt,
      );
      final nightWakeRationale = _normalizeRationale(
        map['nightWakeRationale'] as String?,
        isPt: isPt,
      );
      return AiSuggestion(
        nextNapTime: _normalizeTime(map['nextNapTime'] as String?),
        nextNapRationale: nextNapRationale,
        bedtimeRoutineStart: _normalizeTime(map['bedtimeRoutineStart'] as String?),
        bedtimeRationale: bedtimeRationale,
        nightWakeTime: _normalizeTime(map['nightWakeTime'] as String?),
        nightWakeRationale: nightWakeRationale,
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return const AiSuggestion(error: 'Could not parse AI response');
    }
  }

  static String? _normalizeTime(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
    return v;
  }

  static String? _normalizeRationale(String? text, {required bool isPt}) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return null;
    if (!isPt) return value;

    return value
        .replaceAll(RegExp(r'\bwake\s*time\b', caseSensitive: false), 'tempo acordado')
        .replaceAll(RegExp(r'\bwake\s*window\b', caseSensitive: false), 'janela de vigília')
        .replaceAll(RegExp(r'\bwake\s*windows\b', caseSensitive: false), 'janelas de vigília');
  }
}

// Backward-compatible adapter for existing call sites.
class GeminiService {
  GeminiService._();

  static Future<AiSuggestion?> getSuggestions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) {
    return NvidiaService.getSuggestions(
      apiKey: apiKey,
      profile: profile,
      entries: entries,
      languageCode: languageCode,
      preferredModel: preferredModel,
    );
  }
}
