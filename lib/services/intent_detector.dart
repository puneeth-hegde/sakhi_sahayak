import 'dart:math';

enum IntentType { assist, report }

class IntentResult {
  final IntentType intent;
  final double confidence;

  IntentResult({required this.intent, required this.confidence});
}

class IntentDetector {
  // Assist keywords (General help)
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
    'scheme',
    'government',
    'apply',
    'kaise',
    'kya',
    'kab',
    'kahan',
    'madad',
    'bimaar',
    'yojna'
  ];

  // Report keywords (Safety & Emergency)
  // EXPANDED LIST for better detection
  static const List<String> reportKeywords = [
    'harass', 'assault', 'touch', 'touched', 'follow', 'followed', 'following',
    'stole', 'stealing', 'threat', 'threatened', 'violence', 'abuse', 'rape',
    'attack', 'attacked', 'attacking', 'danger', 'scared', 'afraid',
    'emergency',
    'police', 'help me', 'save me',
    // Hindi / Hinglish
    'pareshan', 'mara', 'chhua', 'peecha', 'dhoka', 'maar', 'bachao', 'dar',
    'police', 'gunda'
  ];

  final double reportThreshold;

  // Lowered threshold slightly to prioritize safety
  IntentDetector({this.reportThreshold = 0.4});

  Future<IntentResult> detectIntent(String text) async {
    final s = text.toLowerCase().trim();

    // tokenize to avoid accidental substring matches
    final tokens = s.split(RegExp(r'\s+|[.,;!?]'));

    int assistScore = 0;
    int reportScore = 0;

    // 1. Token Match
    for (final token in tokens) {
      if (assistKeywords.contains(token)) assistScore += 1;
      // Check for partial matches for safety keywords (e.g., "following" contains "follow")
      if (reportKeywords.any((k) => token.contains(k))) reportScore += 5;
    }

    // 2. Phrase Match (Stronger Signal)
    for (final phrase in reportKeywords.where((p) => p.contains(' '))) {
      if (s.contains(phrase)) reportScore += 10;
    }

    final total = max(1, assistScore + reportScore);
    final reportConf = reportScore / total;
    final assistConf = assistScore / total;

    // SAFETY FIRST LOGIC:
    // If any strong report keyword is found, bias heavily towards report
    if (reportScore > 0) {
      return IntentResult(intent: IntentType.report, confidence: 0.9);
    }

    // Default to Assist if no safety keywords found
    return IntentResult(intent: IntentType.assist, confidence: 0.8);
  }
}
