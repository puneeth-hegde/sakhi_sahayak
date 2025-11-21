import 'dart:math';

enum IntentType { assist, report }

class IntentResult {
  final IntentType intent;
  final double confidence;

  IntentResult({required this.intent, required this.confidence});
}

class IntentDetector {
  // Assist keywords (English + Hindi)
  static const List<String> assistKeywords = [
    'how',
    'what',
    'when',
    'where',
    'steps',
    'help',
    'fever',
    'pain',
    'sick',
    'treatment',
    'medicine',
    'kaise',
    'kya',
    'kab',
    'kahan',
    'madad',
    'bimaar',
  ];

  // Report keywords (English + Hindi)
  static const List<String> reportKeywords = [
    'harass',
    'assault',
    'touch',
    'touched',
    'followed',
    'stole',
    'threat',
    'violence',
    'abuse',
    'rape',
    'attack',
    'pareshan',
    'mara',
    'chhua',
    'peecha',
    'dhoka',
    'maar',
    'followed me',
    'touched me',
    'attacked me',
  ];

  final double reportThreshold;

  IntentDetector({this.reportThreshold = 0.6});

  Future<IntentResult> detectIntent(String text) async {
    final s = text.toLowerCase().trim();

    // tokenize to avoid accidental substring matches
    final tokens = s.split(RegExp(r'\s+|[.,;!?]'));

    int assistScore = 0;
    int reportScore = 0;

    for (final token in tokens) {
      if (assistKeywords.contains(token)) assistScore += 1;
      if (reportKeywords.contains(token)) reportScore += 4;
    }

    // phrase-level check
    for (final phrase in reportKeywords.where((p) => p.contains(' '))) {
      if (s.contains(phrase)) reportScore += 4;
    }

    final total = max(1, assistScore + reportScore);
    final reportConf = reportScore / total;
    final assistConf = assistScore / total;

    // High-confidence report → force report
    if (reportConf >= reportThreshold && reportScore > assistScore) {
      return IntentResult(intent: IntentType.report, confidence: reportConf);
    }

    // Assist detected normally
    if (assistScore > 0) {
      return IntentResult(intent: IntentType.assist, confidence: assistConf);
    }

    // fallback → default assist with low confidence
    return IntentResult(intent: IntentType.assist, confidence: 0.35);
  }
}
