import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../knowledge/sleep_knowledge_base.dart';
import '../models/ai_suggestion.dart';
import '../models/baby_profile.dart';
import '../models/entry.dart';
import '../models/sleep_window_prediction.dart';

class NvidiaService {
  NvidiaService._();

  static const _invokeUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const _requestTimeout = Duration(seconds: 45);

  static Future<AiSuggestion?> getSuggestions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) async {
    if (apiKey.trim().isEmpty) return null;
    if (entries.isEmpty) {
      return AiSuggestion(
        error: languageCode == 'pt'
            ? 'Não há dados suficientes para gerar sugestões. Adicione registros de sono primeiro.'
            : 'Not enough data to generate suggestions. Please add sleep records first.',
      );
    }
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
        final stopwatch = Stopwatch()..start();
        try {
          debugPrint(
            '[AI_SUGGESTION] NVIDIA request start model=$modelName entries=${entries.length} promptChars=${prompt.length}',
          );

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
              .timeout(_requestTimeout);

          debugPrint(
            '[AI_SUGGESTION] NVIDIA response model=$modelName status=${response.statusCode} elapsedMs=${stopwatch.elapsedMilliseconds} bodyChars=${response.body.length}',
          );

          if (response.statusCode >= 400) {
            final body = response.body;
            if (_isModelNotSupportedError(body)) {
              lastError = body;
              debugPrint(
                '[AI_SUGGESTION] NVIDIA unsupported model=$modelName elapsedMs=${stopwatch.elapsedMilliseconds}',
              );
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
          debugPrint(
            '[AI_SUGGESTION] NVIDIA parse start model=$modelName elapsedMs=${stopwatch.elapsedMilliseconds} contentChars=${text.length}',
          );
          return _parseResponse(text, isPt: isPt);
        } on TimeoutException catch (e) {
          lastError = e;
          debugPrint(
            '[AI_SUGGESTION] NVIDIA timeout model=$modelName afterMs=${stopwatch.elapsedMilliseconds} timeoutMs=${_requestTimeout.inMilliseconds}',
          );
        } catch (e) {
          lastError = e;
          if (!_isModelNotSupportedError(e.toString())) {
            debugPrint(
              '[AI_SUGGESTION] NVIDIA error model=$modelName elapsedMs=${stopwatch.elapsedMilliseconds}: $e',
            );
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

  static Future<List<SleepWindowPrediction>?> getSchedulePredictions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) async {
    if (apiKey.trim().isEmpty || entries.isEmpty) return null;

    final modelsToTry = <String>[
      if (preferredModel != null && preferredModel.trim().isNotEmpty)
        preferredModel.trim(),
      'meta/llama-4-maverick-17b-128e-instruct',
      'meta/llama-3.1-70b-instruct',
    ].toSet().toList();

    try {
      final isPt = languageCode == 'pt';
      final prompt = _buildSchedulePrompt(
        profile: profile,
        entries: entries,
        isPt: isPt,
      );

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
                  'temperature': 0.2,
                  'stream': false,
                }),
              )
              .timeout(const Duration(seconds: 45));

          if (response.statusCode >= 400) continue;

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final choices = decoded['choices'] as List;
          final first = choices.first as Map<String, dynamic>;
          final message = first['message'] as Map<String, dynamic>;
          final text = (message['content'] as String?) ?? '';

          return _parseScheduleResponse(text, isPt: isPt);
        } catch (e) {
          debugPrint('NVIDIA schedule error model=$modelName: $e');
        }
      }
    } catch (e) {
      debugPrint('NvidiaService schedule error: $e');
    }
    return null;
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
    final parts = targetBed.split(':');
    final bedHour = int.tryParse(parts[0]) ?? 19;
    final bedMin = int.tryParse(parts.length > 1 ? parts[1] : '30') ?? 30;
    final totalBedMin = bedHour * 60 + bedMin;
    final startRoutineMin = totalBedMin - routineMin;
    final startHour = (startRoutineMin ~/ 60) % 24;
    final startMin = startRoutineMin % 60;
    final routineStartExact = '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')}';

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
1. Se o bebê ESTIVER DORMINDO AGORA: calcule a hora que ele deve ACORDAR. Analise o histórico recente para descobrir a duração média das sonecas/sonos NESSE MESMO HORÁRIO. Use a base de conhecimento apenas como fallback caso não haja dados suficientes no histórico.
2. Se o bebê estiver ACORDADO e for período diurno: horário ideal da PRÓXIMA SONECA (use a janela de vigília apropriada). Sugira o intervalo correspondente (ex: HH:mm - HH:mm).
3. Conflito Soneca vs Rotina: Se for fim da tarde e a próxima soneca for colidir com a rotina noturna ($routineStartExact) ou terminar a menos de 45 min dela, NÃO sugira uma soneca normal. Você deve decidir entre: a) Sugerir uma "soneca ponte" curta (30-40 min); b) Pular a soneca (deixando nextNapTime null) e sugerir antecipar o início da rotina noturna em bedtimeRoutineStart.
4. Soneca ponte NUNCA deve ser sugerida de manhã.
5. Horário para INICIAR A ROTINA NOTURNA: A rotina dura $routineMin minutos e o objetivo é dormir às $targetBed. Normalmente começa às $routineStartExact. Se for sugerir a rotina, você pode usar esse horário ou antecipá-lo caso decida pular a última soneca (conforme regra 3).

IMPORTANTE DE IDIOMA:
- Responda em português do Brasil
- Não use termos em inglês como "wake time" ou "wake window"; use "tempo acordado" ou "janela de vigília"

RESPONDA ESTRITAMENTE com JSON válido. NÃO escreva nenhum raciocínio, não explique os passos, e não adicione texto de introdução ou conclusão. O formato exato (iniciando e terminando com chaves) DEVE ser:
{"wakeUpTime":"HH:mm|null","wakeUpRationale":"1 frase explicando","nextNapTime":"HH:mm - HH:mm|null","nextNapRationale":"1 frase explicando","bedtimeRoutineStart":"HH:mm|null","bedtimeRationale":"1 frase explicando"}''';
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
1. If the baby IS CURRENTLY SLEEPING: calculate the expected WAKE UP time. Analyze the recent history to find the average duration of sleep/naps AT THIS SAME TIME. Use the knowledge base only as a fallback if there is not enough historical data.
2. If the baby is AWAKE and it's DAYTIME: ideal time for the NEXT NAP (use age-appropriate wake window). Suggest the range (e.g., HH:mm - HH:mm).
3. Nap vs Routine Conflict: If it is late afternoon and the next nap will collide with the night routine ($routineStartExact) or end less than 45 mins before it, DO NOT suggest a normal nap. You must decide between: a) Suggesting a short "bridge nap" (30-40 min); b) Skipping the nap (leaving nextNapTime null) and suggesting an earlier bedtimeRoutineStart.
4. Never suggest a bridge nap in the morning.
5. Time to START THE NIGHT ROUTINE: The routine takes $routineMin minutes and the goal is to sleep at $targetBed. It normally starts at $routineStartExact. If suggesting the routine, use this time or an earlier time if you decided to skip the last nap (per rule 3).

RESPOND STRICTLY with valid JSON. DO NOT write any reasoning, do not explain your steps, and do not add any introductory or concluding text. The exact format (starting and ending with curly braces) MUST be:
{"wakeUpTime":"HH:mm|null","wakeUpRationale":"1 sentence explanation","nextNapTime":"HH:mm - HH:mm|null","nextNapRationale":"1 sentence explanation","bedtimeRoutineStart":"HH:mm|null","bedtimeRationale":"1 sentence explanation"}''';
    }
  }

  static String _buildSchedulePrompt({
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required bool isPt,
  }) {
    final rag = SleepKnowledgeBase.getContext(profile.birthdate, isPt: isPt);
    final ageStr = profile.getAgeString(isPt: isPt);
    final targetBed = profile.targetBedtimeString;
    final history = _formatHistory(entries, isPt: isPt);

    if (isPt) {
      return '''Você é um especialista em sono infantil.
PERFIL: Idade: $ageStr. Dormir: $targetBed.
DIRETRIZES:
$rag
HISTÓRICO RECENTE:
$history

TAREFA:
Crie o cronograma ideal de sono para o DIA INTEIRO (hoje/amanhã), começando pelo despertar da manhã até o sono noturno.
Use as médias reais de duração do histórico, e as janelas de vigília recomendadas para a idade.
Divida nos períodos exatos: "morning", "midday", "afternoon", "evening", "night".

RESPONDA ESTRITAMENTE EM JSON VÁLIDO. Não escreva texto fora do JSON. Formato:
{
  "predictions": [
    {
      "period": "morning",
      "periodName": "🌅 Manhã",
      "windows": [
        {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Explicação curta"},
        {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Explicação curta"}
      ]
    }
  ]
}''';
    } else {
      return '''You are a pediatric sleep expert.
PROFILE: Age: $ageStr. Target Bedtime: $targetBed.
GUIDELINES:
$rag
RECENT HISTORY:
$history

TASK:
Create the ideal full-day sleep schedule, starting from the morning wake up to the night sleep.
Use actual averages from the history, and age-appropriate wake windows.
Divide into periods exactly: "morning", "midday", "afternoon", "evening", "night".

RESPOND STRICTLY IN VALID JSON. No text outside JSON. Format:
{
  "predictions": [
    {
      "period": "morning",
      "periodName": "🌅 Morning",
      "windows": [
        {"isAwake": true, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Short explanation"},
        {"isAwake": false, "startTime": "HH:mm", "endTime": "HH:mm", "rationale": "Short explanation"}
      ]
    }
  ]
}''';
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

    String context = isPt
        ? 'Último período registrado: $latestPeriod. Dormindo agora: $sleepingText.'
        : 'Last recorded period: $latestPeriod. Currently sleeping: $sleepingText.';

    if (!currentlySleeping && latest.wokeUp != null) {
      final wakeStr = _fmt(latest.wokeUp!);
      context += isPt
          ? '\nATENÇÃO: O bebê está acordado. O último despertar (hora em que acordou) foi às $wakeStr. Calcule a próxima soneca a partir de $wakeStr.'
          : '\nATTENTION: The baby is awake. The last wake-up time was at $wakeStr. Calculate the next nap starting from $wakeStr.';

      if (!latest.isDay) {
        context += isPt
            ? '\nRegra importante: Como o último registro foi um sono NOTURNO, esse último despertar significa que o bebê já está acordado pela manhã. A primeira janela de vigília da manhã começa exatamente às $wakeStr (ex: se acordou 5:30 e a janela é de 2h, a primeira soneca será calculada a partir de 5:30).'
            : '\nImportant rule: Since the last record was a NIGHT sleep, this last wake-up means the baby is already awake for the morning. The first wake window of the morning starts exactly at $wakeStr (e.g., if woke up at 5:30 and the window is 2h, the first nap will be calculated from 5:30).';
      }
    }

    return context;
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
    cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').trim();

    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    
    if (jsonStart != -1 && jsonEnd > jsonStart) {
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
          (map['wakeUpRationale'] as String?) ?? (map['nightWakeRationale'] as String?),
          isPt: isPt,
        );
        return AiSuggestion(
          nextNapTime: _normalizeTime(map['nextNapTime'] as String?),
          nextNapRationale: nextNapRationale,
          bedtimeRoutineStart: _normalizeTime(map['bedtimeRoutineStart'] as String?),
          bedtimeRationale: bedtimeRationale,
          nightWakeTime: _normalizeTime((map['wakeUpTime'] as String?) ?? (map['nightWakeTime'] as String?)),
          nightWakeRationale: nightWakeRationale,
          generatedAt: DateTime.now(),
        );
      } catch (e) {
        debugPrint('AI parse error (jsonDecode): $e');
        debugPrint('AI cleaned response: $cleaned');
      }
    } else {
      debugPrint('AI parse error: No valid braces found. Start: $jsonStart, End: $jsonEnd');
      debugPrint('AI raw response: $raw');
    }

    final fallback = _parseLooseJsonLike(cleaned, isPt: isPt);
    if (fallback != null) {
      debugPrint('AI parse recovered via loose parser');
      return fallback;
    }

    debugPrint('AI parse failed completely. Raw: $raw');
    return const AiSuggestion(error: 'Could not parse AI response');
  }

  static AiSuggestion? _parseLooseJsonLike(String text, {required bool isPt}) {
    String? pick(String key) {
      final quoted = RegExp('"$key"\\s*:\\s*"([^"]*)"');
      final quotedMatch = quoted.firstMatch(text);
      if (quotedMatch != null) return quotedMatch.group(1);

      final bare = RegExp('"$key"\\s*:\\s*([^,}\\n]+)');
      final bareMatch = bare.firstMatch(text);
      if (bareMatch == null) return null;
      return bareMatch.group(1)?.trim().replaceAll('"', '');
    }

    final nextNapTime = _normalizeTime(pick('nextNapTime'));
    final nextNapRationale = _normalizeRationale(
      pick('nextNapRationale'),
      isPt: isPt,
    );
    final bedtimeRoutineStart = _normalizeTime(pick('bedtimeRoutineStart'));
    final bedtimeRationale = _normalizeRationale(
      pick('bedtimeRationale'),
      isPt: isPt,
    );
    final nightWakeTime = _normalizeTime(pick('wakeUpTime') ?? pick('nightWakeTime'));
    final nightWakeRationale = _normalizeRationale(
      pick('wakeUpRationale') ?? pick('nightWakeRationale'),
      isPt: isPt,
    );

    final hasAnyContent = nextNapTime != null ||
        bedtimeRoutineStart != null ||
        nightWakeTime != null ||
        (nextNapRationale?.isNotEmpty ?? false) ||
        (bedtimeRationale?.isNotEmpty ?? false) ||
        (nightWakeRationale?.isNotEmpty ?? false);

    if (!hasAnyContent) return null;

    return AiSuggestion(
      nextNapTime: nextNapTime,
      nextNapRationale: nextNapRationale,
      bedtimeRoutineStart: bedtimeRoutineStart,
      bedtimeRationale: bedtimeRationale,
      nightWakeTime: nightWakeTime,
      nightWakeRationale: nightWakeRationale,
      generatedAt: DateTime.now(),
    );
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

  static List<SleepWindowPrediction>? _parseScheduleResponse(String raw, {required bool isPt}) {
    String cleaned = raw.trim();
    cleaned = cleaned.replaceAll(RegExp(r'```[a-zA-Z]*\n?'), '').trim();
    final jsonStart = cleaned.indexOf('{');
    final jsonEnd = cleaned.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd > jsonStart) {
      try {
        final map = jsonDecode(cleaned.substring(jsonStart, jsonEnd + 1))
            as Map<String, dynamic>;
        final list = map['predictions'] as List;
        return list.map((p) {
          final pMap = p as Map<String, dynamic>;
          final wList = pMap['windows'] as List;
          final windows = wList.map((w) {
            final wMap = w as Map<String, dynamic>;
            return SleepWindow(
              isAwake: wMap['isAwake'] as bool? ?? true,
              startTime: wMap['startTime'] as String? ?? '--:--',
              endTime: wMap['endTime'] as String?,
              rationale: wMap['rationale'] as String?,
            );
          }).toList();
          return SleepWindowPrediction(
            period: pMap['period'] as String? ?? 'day',
            periodName: pMap['periodName'] as String? ?? 'Period',
            windows: windows,
          );
        }).toList();
      } catch (e) {
        debugPrint('AI schedule parse error: $e');
      }
    }
    return null;
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

  static Future<List<SleepWindowPrediction>?> getSchedulePredictions({
    required String apiKey,
    required BabyProfile profile,
    required List<SleepEntry> entries,
    required String languageCode,
    String? preferredModel,
  }) {
    return NvidiaService.getSchedulePredictions(
      apiKey: apiKey,
      profile: profile,
      entries: entries,
      languageCode: languageCode,
      preferredModel: preferredModel,
    );
  }
}
