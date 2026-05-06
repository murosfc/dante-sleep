import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';
import '../models/sleep_window_prediction.dart';

class GeminiService {
  GeminiService._();

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

    final modelsToTry = <String>{
      if (preferredModel != null && preferredModel.trim().isNotEmpty)
        preferredModel.trim(),
      'meta/llama-4-maverick-17b-128e-instruct',
      'meta/llama-3.1-70b-instruct',
    }.toList();

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
          return _parseResponse(text);
        } catch (e) {
          lastError = e;
          if (!_isModelNotSupportedError(e.toString())) {
            debugPrint('GeminiService error ($modelName): $e');
            return AiSuggestion(error: e.toString());
          }
        }
      }

      final message =
          lastError?.toString() ??
          'No compatible NVIDIA model found for this API key/project.';
      debugPrint('GeminiService model fallback error: $message');
      return AiSuggestion(error: message);
    } catch (e) {
      debugPrint('GeminiService error: $e');
      return AiSuggestion(error: e.toString());
    }
  }

  static Future<List<SleepWindowPrediction>?> getSleepWindowPredictions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) async {
    if (apiKey.trim().isEmpty) return null;

    final modelsToTry = <String>{
      if (preferredModel != null && preferredModel.trim().isNotEmpty)
        preferredModel.trim(),
      'meta/llama-4-maverick-17b-128e-instruct',
      'meta/llama-3.1-70b-instruct',
    }.toList();

    try {
      final isPt = languageCode == 'pt';
      final prompt = _buildSleepWindowPrompt(
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
                  'max_tokens': 1024,
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
              'GeminiService error ${response.statusCode}: $body',
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
          return _parseSleepWindowResponse(text, isPt);
        } catch (e) {
          lastError = e;
          if (!_isModelNotSupportedError(e.toString())) {
            debugPrint('GeminiService error ($modelName): $e');
            return null;
          }
        }
      }

      final message =
          lastError?.toString() ??
          'No compatible NVIDIA model found for this API key/project.';
      debugPrint('GeminiService model fallback error: $message');
      return null;
    } catch (e) {
      debugPrint('GeminiService error: $e');
      return null;
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
    final currentStatus = _describeCurrentStatus(entries, isPt: isPt);
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

ESTADO ATUAL:
$currentStatus

DIRETRIZES PARA A FAIXA ETÁRIA (use-as como referência de suporte, mas priorize os registros reais):
$rag

HISTÓRICO COMPLETO DOS CARTÕES (mais recente primeiro):
$history

Determine:
1. Analise o histórico e o wake window máximo da idade. Se o tempo até o horário alvo exceder o wake window máximo, VOCÊ DEVE SUGERIR UMA SONECA PONTE (cat nap) ao invés da rotina noturna.
2. O horário $targetBed é flexível. É preferível sugerir uma soneca ponte de 30-40 min (e empurrar um pouco o horário de dormir) do que deixar o bebê ficar exausto (overtired). A janela de sono após uma soneca ponte costuma ser mais curta que o normal.
3. Se for SONECA: preencha "nextNapTime" e deixe os campos de bedtime como "null".
4. Se for SONO NOTURNO: preencha "bedtimeRoutineStart" (considere $routineMin min de rotina) e deixe os campos de nap como "null".

RESPONDA APENAS com JSON válido, sem texto adicional:
{"nextNapTime":"HH:mm ou HH:mm~HH:mm ou null","nextNapRationale":"explicação ou null","bedtimeRoutineStart":"HH:mm ou HH:mm~HH:mm ou null","bedtimeRationale":"explicação ou null"}''';
    } else {
      return '''You are an evidence-based pediatric sleep expert. Provide precise, practical suggestions.

CURRENT TIME: $nowStr

BABY PROFILE:
- Name: $babyName  Age: $ageStr  Sex: $sexStr
- Feeding: $feedingStr
- Complementary food started: $complementaryStr
- Night routine duration: $routineMin minutes
- Target bedtime: $targetBed

CURRENT STATUS:
$currentStatus

GUIDELINES FOR AGE RANGE (use them as supporting reference, but prioritize the actual sleep records):
$rag

COMPLETE HISTORY FROM ALL CARDS (newest first):
$history

Determine:
1. Analyze the history and maximum wake window. If the time until target bedtime exceeds the maximum wake window, YOU MUST SUGGEST A BRIDGE NAP (cat nap) instead of the night routine.
2. The $targetBed time is flexible. It is better to suggest a 30-40 min bridge nap (and push bedtime slightly) than to let the baby get overtired. The wake window after a bridge nap is usually shorter than normal.
3. If it's a NAP: fill "nextNapTime" and set bedtime fields to "null".
4. If it's the NIGHT SLEEP: fill "bedtimeRoutineStart" (consider $routineMin min routine) and set nap fields to "null".

RESPOND ONLY with valid JSON, no additional text:
{"nextNapTime":"HH:mm or HH:mm~HH:mm or null","nextNapRationale":"explanation or null","bedtimeRoutineStart":"HH:mm or HH:mm~HH:mm or null","bedtimeRationale":"explanation or null"}''';
    }
  }

  static String _formatHistory(List<SleepEntry> entries, {required bool isPt}) {
    if (entries.isEmpty) {
      return isPt ? 'Nenhum registro ainda.' : 'No records yet.';
    }
    final buf = StringBuffer();
    for (final e in entries) {
      final slept = e.slept != null ? _fmt(e.slept!) : '--:--';
      final woke = e.wokeUp != null ? _fmt(e.wokeUp!) : '--:--';
      final duration = (e.slept != null && e.wokeUp != null)
          ? '${e.wokeUp!.difference(e.slept!).inHours}h${(e.wokeUp!.difference(e.slept!).inMinutes % 60).toString().padLeft(2, '0')}m'
          : null;
      final period = e.isDay
          ? (isPt ? 'soneca' : 'nap')
          : (isPt ? 'noite' : 'night');
      final label = (e.slept != null && e.wokeUp == null)
          ? (isPt ? 'soneca atual' : 'current nap')
          : period;
      final bottleInfo = _formatBottleInfo(e, isPt: isPt);
      final line = StringBuffer();

      if (isPt) {
        line.write('- Dormiu $slept');
        line.write(e.wokeUp != null ? ' → Acordou $woke' : ' → Ainda dormindo');
        if (duration != null) {
          line.write(' ($duration)');
        }
        line.write(' [$label]');
        line.write(' [$bottleInfo]');
      } else {
        line.write('- Slept $slept');
        line.write(e.wokeUp != null ? ' → Woke $woke' : ' → Still sleeping');
        if (duration != null) {
          line.write(' ($duration)');
        }
        line.write(' [$label]');
        line.write(' [$bottleInfo]');
      }

      buf.writeln(line.toString());
    }
    return buf.toString().trimRight();
  }

  static String _formatBottleInfo(SleepEntry entry, {required bool isPt}) {
    if (!entry.bottle) {
      return isPt ? 'sem mamada' : 'no bottle';
    }
    final bottleTime = entry.bottleTime != null
        ? _fmt(entry.bottleTime!)
        : null;
    if (bottleTime != null) {
      return isPt ? 'mamou às $bottleTime' : 'bottle at $bottleTime';
    }
    return isPt ? 'mamou' : 'bottle';
  }

  static String _describeCurrentStatus(
    List<SleepEntry> entries, {
    required bool isPt,
  }) {
    if (entries.isEmpty) {
      return isPt ? 'Sem registros de sono.' : 'No sleep records.';
    }

    SleepEntry? ongoing;
    for (final entry in entries) {
      if (entry.slept != null && entry.wokeUp == null) {
        ongoing = entry;
        break;
      }
    }

    if (ongoing != null && ongoing.slept != null) {
      final when = _fmt(ongoing.slept!);
      final period = ongoing.isDay
          ? (isPt ? 'soneca' : 'nap')
          : (isPt ? 'noite' : 'night');
      return isPt
          ? 'Atualmente dormindo desde $when ($period) com base no último cartão.'
          : 'Currently asleep since $when ($period) based on the latest card.';
    }

    for (final entry in entries) {
      if (entry.wokeUp != null) {
        final when = _fmt(entry.wokeUp!);
        final period = entry.isDay
            ? (isPt ? 'soneca' : 'nap')
            : (isPt ? 'noite' : 'night');
        return isPt
            ? 'Último registro mostra que acordou às $when após uma $period.'
            : 'Last record shows waking at $when after a $period.';
      }
    }

    return isPt
        ? 'Não há informações suficientes para determinar o estado atual.'
        : 'Not enough information to determine current status.';
  }

  static String _buildSleepWindowPrompt({
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
    final history = _formatHistory(entries, isPt: isPt);
    final now = DateTime.now();
    final nowStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final targetBed = profile.targetBedtimeHour != null && profile.targetBedtimeMinute != null
        ? '${profile.targetBedtimeHour.toString().padLeft(2, '0')}:${profile.targetBedtimeMinute.toString().padLeft(2, '0')}'
        : '19:30';

    if (isPt) {
      return '''Você é um especialista em sono infantil baseado em evidências. Analise o histórico completo e preveja as janelas de sono/acordado para o dia atual.

HORÁRIO ATUAL: $nowStr

PERFIL DO BEBÊ:
- Nome: $babyName  Idade: $ageStr

DIRETRIZES GERAIS DA FAIXA ETÁRIA (Use como apoio, mas OS REGISTROS REAIS DO BEBÊ TÊM PRIORIDADE MÁXIMA):
$rag

HISTÓRICO COMPLETO DOS ÚLTIMOS 7 DIAS (mais recente primeiro):
$history

REGRAS IMPORTANTES:
1. As listas podem ter vários blocos (ex: acordado, depois soneca ponte, depois acordado).
2. O período "evening" abrange o fim do dia ANTES das $targetBed. Não coloque o sono noturno no "evening".
3. O sono principal (Night Sleep) DEVE ficar APENAS na lista "night", iniciando a partir das $targetBed. A hora final desse sono deve ser sua previsão de quando o bebê acordará na manhã seguinte (tente ser consistente com a hora que ele costuma acordar, ex: se a manhã hoje começou às 07:35, a noite deve terminar perto das 07:35).
4. Respeite os limites das janelas de sono (Wake Windows). Se o histórico do bebê mostrar que ele costuma fazer uma soneca ponte no final da tarde, ou se a janela for ficar muito longa, você DEVE inserir uma soneca curta (soneca ponte de 30-40 min) no "evening".
5. Garanta que o horário final de um bloco seja igual ao horário inicial do bloco seguinte, mantendo a continuidade do dia.

RESPONDA APENAS com JSON válido, sem texto adicional:
{
  "morning": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "midday": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "afternoon": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "evening": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Soneca ponte"},
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "night": [
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ]
}''';
    } else {
      return '''You are an evidence-based pediatric sleep expert. Analyze the complete history and predict sleep/awake windows for today.

CURRENT TIME: $nowStr

BABY PROFILE:
- Name: $babyName  Age: $ageStr

GENERAL GUIDELINES FOR AGE RANGE (Use as support, but the BABY'S ACTUAL RECORDS HAVE MAXIMUM PRIORITY):
$rag

COMPLETE HISTORY FROM LAST 7 DAYS (newest first):
$history

IMPORTANT RULES:
1. Lists can have multiple blocks (e.g. awake, then bridge nap, then awake again).
2. The "evening" period covers the end of the day BEFORE $targetBed. Do NOT put the main night sleep in "evening".
3. The main night sleep MUST be placed ONLY in the "night" list, starting from $targetBed onwards. The end time should be your prediction for tomorrow's wake up time (try to be consistent with today's wake up time, e.g., if morning started at 07:35 today, night should end near 07:35).
4. Respect wake window limits. If the baby's history shows they usually take a bridge nap in the late afternoon, or if the wake window will be too long, you MUST insert a short bridge nap (30-40 min) in the "evening".
5. Ensure the end time of one block matches the start time of the next block to maintain the continuity of the day.

RESPOND ONLY with valid JSON, no additional text:
{
  "morning": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "midday": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "afternoon": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "evening": [
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"},
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Bridge nap"},
    {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm"}
  ],
  "night": [
    {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm"}
  ]
}''';
    }
  }

  static List<SleepWindowPrediction>? _parseSleepWindowResponse(String raw, bool isPt) {
    String cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();

    final jsonText = _extractJsonObject(cleaned);
    if (jsonText == null) return null;

    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      final periods = [
        {'key': 'morning', 'name': isPt ? '🌅 Manhã' : '🌅 Morning'},
        {'key': 'midday', 'name': isPt ? '🌞 Meio do dia' : '🌞 Midday'},
        {'key': 'afternoon', 'name': isPt ? '🌇 Tarde' : '🌇 Afternoon'},
        {'key': 'evening', 'name': isPt ? '🌆 Noite' : '🌆 Evening'},
        {'key': 'night', 'name': isPt ? '🌙 Noite' : '🌙 Night'},
      ];

      final predictions = <SleepWindowPrediction>[];

      for (final period in periods) {
        final key = period['key'] as String;
        final name = period['name'] as String;
        final windowsData = map[key];

        if (windowsData is List) {
          final windows = <SleepWindow>[];
          for (final windowData in windowsData) {
            if (windowData is Map<String, dynamic>) {
              final isAwake = windowData['isAwake'] as bool? ?? true;
              final startTime = windowData['startTime'] as String?;
              final endTime = windowData['endTime'] as String?;
              final rationale = windowData['rationale'] as String?;

              if (startTime != null) {
                windows.add(SleepWindow(
                  isAwake: isAwake,
                  startTime: startTime,
                  endTime: endTime,
                  rationale: rationale,
                ));
              }
            }
          }

          if (windows.isNotEmpty) {
            predictions.add(SleepWindowPrediction(
              period: key,
              periodName: name,
              windows: windows,
            ));
          }
        }
      }

      return predictions.isNotEmpty ? predictions : null;
    } catch (_) {
      return null;
    }
  }

  static AiSuggestion _parseResponse(String raw) {
    String cleaned = raw.trim();
    // Strip markdown code fences
    cleaned = cleaned.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();

    final jsonText = _extractJsonObject(cleaned);
    if (jsonText == null) {
      return const AiSuggestion(error: 'Could not parse AI response');
    }

    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      
      String? parseStringOrNull(dynamic value) {
        if (value == null) return null;
        final str = value.toString().trim();
        if (str.toLowerCase() == 'null') return null;
        return str;
      }

      return AiSuggestion(
        nextNapTime: parseStringOrNull(map['nextNapTime']),
        nextNapRationale: parseStringOrNull(map['nextNapRationale']),
        bedtimeRoutineStart: parseStringOrNull(map['bedtimeRoutineStart']),
        bedtimeRationale: parseStringOrNull(map['bedtimeRationale']),
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return const AiSuggestion(error: 'Could not parse AI response');
    }
  }

  static String? _extractJsonObject(String text) {
    final start = text.indexOf('{');
    if (start == -1) return null;

    int depth = 0;
    for (int i = start; i < text.length; i++) {
      final char = text[i];
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) {
          return text.substring(start, i + 1);
        }
      }
    }

    return null;
  }

  static String _fmt(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
