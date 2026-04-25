import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';

class GeminiService {
  GeminiService._();

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
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash-latest',
      'gemini-1.5-flash',
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
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey.trim(),
            generationConfig: GenerationConfig(
              temperature: 0.3,
              maxOutputTokens: 512,
            ),
          );

          final response = await model.generateContent([Content.text(prompt)]);
          final text = response.text ?? '';
          return _parseResponse(text);
        } catch (e) {
          lastError = e;
          if (!_isModelNotSupportedError(e.toString())) {
            debugPrint('GeminiService error ($modelName): $e');
            return AiSuggestion(error: e.toString());
          }
        }
      }

      final message = lastError?.toString() ??
          'No compatible Gemini model found for this API key/project.';
      debugPrint('GeminiService model fallback error: $message');
      return AiSuggestion(error: message);
    } catch (e) {
      debugPrint('GeminiService error: $e');
      return AiSuggestion(error: e.toString());
    }
  }

  static bool _isModelNotSupportedError(String message) {
    final m = message.toLowerCase();
    return m.contains('not found') ||
        m.contains('not supported') ||
        m.contains('listmodels') ||
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

Determine:
1. Horário ideal da PRÓXIMA SONECA (use o wake window adequado para a idade desde o último acordar)
2. Horário para INICIAR A ROTINA NOTURNA (considere $routineMin min de rotina para dormir às $targetBed)

RESPONDA APENAS com JSON válido, sem texto adicional:
{"nextNapTime":"HH:mm","nextNapRationale":"1 frase explicando","bedtimeRoutineStart":"HH:mm","bedtimeRationale":"1 frase explicando"}''';
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

Determine:
1. Ideal time for the NEXT NAP (use appropriate wake window for age since last wake-up)
2. Time to START THE NIGHT ROUTINE ($routineMin min routine to sleep at $targetBed)

RESPOND ONLY with valid JSON, no additional text:
{"nextNapTime":"HH:mm","nextNapRationale":"1 sentence explanation","bedtimeRoutineStart":"HH:mm","bedtimeRationale":"1 sentence explanation"}''';
    }
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

  static AiSuggestion _parseResponse(String raw) {
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
      return AiSuggestion(
        nextNapTime: map['nextNapTime'] as String?,
        nextNapRationale: map['nextNapRationale'] as String?,
        bedtimeRoutineStart: map['bedtimeRoutineStart'] as String?,
        bedtimeRationale: map['bedtimeRationale'] as String?,
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return const AiSuggestion(error: 'Could not parse AI response');
    }
  }
}
