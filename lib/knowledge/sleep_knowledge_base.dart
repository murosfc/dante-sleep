/// Static knowledge base with evidence-based pediatric sleep guidelines.
/// Injected into AI prompts as RAG context.
class SleepKnowledgeBase {
  SleepKnowledgeBase._();

  /// Returns a reasonable fallback range for total night sleep by age.
  /// Values are conservative and aligned with the ranges described below.
  static ({double minHours, double maxHours}) getRecommendedNightSleepHours(
    DateTime? birthdate,
  ) {
    if (birthdate == null) {
      return (minHours: 9.0, maxHours: 11.0);
    }

    final weeks = DateTime.now().difference(birthdate).inDays ~/ 7;
    if (weeks < 6) return (minHours: 8.0, maxHours: 10.0);
    if (weeks < 12) return (minHours: 8.5, maxHours: 10.5);
    if (weeks < 20) return (minHours: 9.0, maxHours: 11.0);
    if (weeks < 28) return (minHours: 9.5, maxHours: 11.5);
    if (weeks < 40) return (minHours: 10.0, maxHours: 12.0);
    if (weeks < 52) return (minHours: 10.0, maxHours: 12.0);
    if (weeks < 70) return (minHours: 10.0, maxHours: 12.0);
    if (weeks < 104) return (minHours: 10.0, maxHours: 12.0);
    return (minHours: 10.0, maxHours: 11.5);
  }

  static String getContext(DateTime? birthdate, {bool isPt = true}) {
    String context;
    if (birthdate == null) {
      context = isPt ? _generalPt : _generalEn;
    } else {
      final weeks = DateTime.now().difference(birthdate).inDays ~/ 7;
      context = _getByWeeks(weeks, isPt: isPt);
    }
    final bridgeNap = isPt ? _bridgeNapPt : _bridgeNapEn;
    return '$context\n\n$bridgeNap';
  }

  static String _getByWeeks(int weeks, {required bool isPt}) {
    if (weeks < 6) return isPt ? _w0_6pt : _w0_6en;
    if (weeks < 12) return isPt ? _w6_12pt : _w6_12en;
    if (weeks < 20) return isPt ? _w12_20pt : _w12_20en;
    if (weeks < 28) return isPt ? _w20_28pt : _w20_28en;
    if (weeks < 40) return isPt ? _w28_40pt : _w28_40en;
    if (weeks < 52) return isPt ? _w40_52pt : _w40_52en;
    if (weeks < 70) return isPt ? _w52_70pt : _w52_70en;
    if (weeks < 104) return isPt ? _w70_104pt : _w70_104en;
    return isPt ? _w104plusPt : _w104plusEn;
  }

  // ─── 0–6 semanas ────────────────────────────────────────────────────────────
  static const _w0_6pt = '''Faixa etária: 0–6 semanas
• Wake windows: 45–60 min
• Total de sono: 14–17 h/dia · 4–6 sonecas irregulares
• Noite: ciclos de 2–3 h, sem ritmo circadiano ainda
• Alimentação a cada 2–3 h impacta diretamente o sono''';

  static const _w0_6en = '''Age: 0–6 weeks
• Wake windows: 45–60 min
• Total sleep: 14–17 h/day · 4–6 irregular naps
• Night: 2–3 h cycles, no circadian rhythm yet
• Feeding every 2–3 h directly affects sleep''';

  // ─── 6–12 semanas ───────────────────────────────────────────────────────────
  static const _w6_12pt = '''Faixa etária: 6–12 semanas
• Wake windows: 60–90 min
• Total de sono: 14–16 h/dia · 4–5 sonecas
• Noite: começa 1 trecho mais longo (~3–4 h)
• Exponha à luz natural de manhã para reforçar o ritmo circadiano''';

  static const _w6_12en = '''Age: 6–12 weeks
• Wake windows: 60–90 min
• Total sleep: 14–16 h/day · 4–5 naps
• Night: one longer stretch (~3–4 h) starts to emerge
• Morning natural light exposure reinforces circadian rhythm''';

  // ─── 3–5 meses ──────────────────────────────────────────────────────────────
  static const _w12_20pt = '''Faixa etária: 3–5 meses
• Wake windows: 1h30–2h
• Total de sono: 14–16 h/dia · 3–4 sonecas
• Noite: trecho longo ~5–6 h · horário ideal: 18h–19h30
• Última soneca deve terminar ~1h30–2h antes de dormir
• Regressão aos 4 meses é normal (reorganização de ciclos)''';

  static const _w12_20en = '''Age: 3–5 months
• Wake windows: 1h30–2h
• Total sleep: 14–16 h/day · 3–4 naps
• Night: long stretch ~5–6 h · ideal bedtime: 6–7:30 PM
• Last nap should end ~1h30–2h before bedtime
• 4-month regression is normal (sleep cycle reorganization)''';

  // ─── 5–7 meses ──────────────────────────────────────────────────────────────
  static const _w20_28pt = '''Faixa etária: 5–7 meses
• Wake windows: 2h–2h30 (WW antes de dormir pode chegar a 2h30)
• Total de sono: 13–15 h/dia · 2–3 sonecas
• Noite: 6–8 h contínuas · horário ideal: 18h30–19h30
• Evitar soneca após 17h — compromete sono noturno
• Introdução alimentar (~6 m) pode alterar levemente o sono''';

  static const _w20_28en = '''Age: 5–7 months
• Wake windows: 2h–2h30 (WW before bed can reach 2h30)
• Total sleep: 13–15 h/day · 2–3 naps
• Night: 6–8 continuous hours · ideal bedtime: 6:30–7:30 PM
• Avoid naps after 5 PM — compromises night sleep
• Solid food intro (~6 m) may slightly alter sleep''';

  // ─── 7–10 meses ─────────────────────────────────────────────────────────────
  static const _w28_40pt = '''Faixa etária: 7–10 meses
• Wake windows: 2h30–3h30
• Total de sono: 12–15 h/dia · 2 sonecas (manhã + tarde)
• Noite: 10–12 h contínuas · horário ideal: 18h30–19h30
• Soneca da manhã: ~1–2 h após acordar
• Soneca da tarde: ~2h30–3h após acordar
• Regressão aos 8–10 m por marcos de desenvolvimento é comum''';

  static const _w28_40en = '''Age: 7–10 months
• Wake windows: 2h30–3h30
• Total sleep: 12–15 h/day · 2 naps (morning + afternoon)
• Night: 10–12 continuous hours · ideal bedtime: 6:30–7:30 PM
• Morning nap: ~1–2 h after wake-up
• Afternoon nap: ~2h30–3h after morning wake-up
• 8–10 month regression from developmental milestones is common''';

  // ─── 10–12 meses ────────────────────────────────────────────────────────────
  static const _w40_52pt = '''Faixa etária: 10–12 meses
• Wake windows: 3h–3h30
• Total de sono: 12–14 h/dia · 2 sonecas
• Noite: 10–12 h · horário ideal: 19h–20h
• Soneca da tarde deve terminar antes das 16h
• Regressão aos 12 m por transição 2→1 soneca é frequente''';

  static const _w40_52en = '''Age: 10–12 months
• Wake windows: 3h–3h30
• Total sleep: 12–14 h/day · 2 naps
• Night: 10–12 h · ideal bedtime: 7–8 PM
• Afternoon nap should end before 4 PM
• 12-month regression during 2-to-1 nap transition is common''';

  // ─── 12–16 meses ────────────────────────────────────────────────────────────
  static const _w52_70pt = '''Faixa etária: 12–16 meses
• Wake windows: 3h–4h30
• Total de sono: 11–14 h/dia · 1–2 sonecas (em transição)
• Noite: 10–12 h · horário ideal: 19h–20h
• Transição para 1 soneca pode levar 1–2 meses, é irregular''';

  static const _w52_70en = '''Age: 12–16 months
• Wake windows: 3h–4h30
• Total sleep: 11–14 h/day · 1–2 naps (transitioning)
• Night: 10–12 h · ideal bedtime: 7–8 PM
• Transition to 1 nap takes 1–2 months and is irregular''';

  // ─── 16–24 meses ────────────────────────────────────────────────────────────
  static const _w70_104pt = '''Faixa etária: 16–24 meses
• Wake windows: 4h–6h
• Total de sono: 11–14 h/dia · 1 soneca (pós-almoço)
• Noite: 10–12 h · horário ideal: 19h30–20h30
• Soneca única: entre 12h30–13h30, duração ~1h30–2h
• Soneca tardia ou longa → adiantar horário noturno''';

  static const _w70_104en = '''Age: 16–24 months
• Wake windows: 4h–6h
• Total sleep: 11–14 h/day · 1 nap (post-lunch)
• Night: 10–12 h · ideal bedtime: 7:30–8:30 PM
• Single nap: between 12:30–1:30 PM, ~1h30–2h duration
• Late or long nap → move bedtime earlier''';

  // ─── 24+ meses ──────────────────────────────────────────────────────────────
  static const _w104plusPt = '''Faixa etária: 2+ anos
• Wake windows: 5h–7h
• Total de sono: 11–13 h/dia · 0–1 soneca
• Noite: 10–12 h · horário ideal: 19h30–20h30
• "Quiet time" se resistir à soneca mas ficar irritadiço à tarde''';

  static const _w104plusEn = '''Age: 2+ years
• Wake windows: 5h–7h
• Total sleep: 11–13 h/day · 0–1 nap
• Night: 10–12 h · ideal bedtime: 7:30–8:30 PM
• "Quiet time" if resisting nap but cranky in the afternoon''';

  // ─── Geral ──────────────────────────────────────────────────────────────────
  static const _generalPt = '''Diretrizes gerais de sono infantil
• 0–3 m: 14–17 h/dia, WW 45 min–1h30
• 3–6 m: 13–16 h/dia, WW 1h30–2h30
• 6–12 m: 12–15 h/dia, WW 2h–3h30
• 1–2 a: 11–14 h/dia, WW 3h–6h
• Bebê cansado demais (overtired) tem MAIS dificuldade de dormir
• Observe sinais: esfregar olhos, bocejos, olhar fixo''';

  static const _generalEn = '''General infant sleep guidelines
• 0–3 m: 14–17 h/day, WW 45 min–1h30
• 3–6 m: 13–16 h/day, WW 1h30–2h30
• 6–12 m: 12–15 h/day, WW 2h–3h30
• 1–2 y: 11–14 h/day, WW 3h–6h
• Overtired baby has MORE difficulty sleeping
• Watch for cues: eye rubbing, yawning, glassy eyes''';

  static const _bridgeNapPt = '''Soneca Ponte (Cat Nap):
• Se a janela de sono até a rotina noturna exceder o limite máximo da idade, sugira uma "soneca ponte" (cat nap).
• Duração ideal da soneca ponte: 15 a 45 minutos (apenas para aliviar a pressão de sono).
• A janela de sono APÓS a soneca ponte costuma ser um pouco MENOR que a janela normal, para não empurrar o sono noturno para muito tarde.''';

  static const _bridgeNapEn = '''Bridge Nap (Cat Nap):
• If the wake window until bedtime exceeds the maximum limit for the age, suggest a "bridge nap" (cat nap).
• Ideal duration: 15 to 45 minutes (just to relieve sleep pressure).
• The wake window AFTER a bridge nap is usually slightly SHORTER than the normal window, so bedtime isn't pushed too late.''';
}
