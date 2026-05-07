import 'dart:convert';
import 'dart:math' as math;

class OfflineSemanticEncoder {
  static const int dimension = 768;

  static const Set<String> _stopwords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from', 'have',
    'has', 'in', 'is', 'it', 'of', 'on', 'or', 'that', 'the', 'their', 'this',
    'to', 'was', 'were', 'will', 'with', 'you', 'your', 'i', 'we', 'they', 'them',
    'me', 'my', 'our', 'us', 'can', 'could', 'should', 'would', 'do', 'does', 'did',
    'not', 'no', 'yes', 'if', 'then', 'than', 'there', 'here', 'what', 'when',
    'where', 'how', 'why', 'which',
  };

  static const Map<String, List<String>> _synonyms = {
    'scheme': ['yojana', 'yojna', 'program', 'plan'],
    'apply': ['register', 'registration', 'application'],
    'register': ['apply', 'registration', 'enroll'],
    'free': ['zero', 'no-cost', 'without-payment'],
    'health': ['medical', 'hospital', 'clinic'],
    'hospital': ['clinic', 'medical', 'health'],
    'insurance': ['coverage', 'protection', 'benefit'],
    'treatment': ['care', 'medicine', 'therapy'],
    'medicine': ['drug', 'treatment', 'care'],
    'fever': ['bukhar', 'jvar'],
    'cough': ['khansi'],
    'pain': ['dard'],
    'help': ['support', 'assistance', 'madad'],
    'police': ['thana', 'law'],
    'woman': ['women', 'female'],
    'child': ['children', 'kid', 'baby'],
    'pregnant': ['pregnancy', 'mother'],
    'government': ['sarkar', 'govt'],
    'benefit': ['subsidy', 'support', 'aid'],
    'income': ['money', 'earnings'],
    'job': ['work', 'employment'],
    'water': ['drinking-water', 'safe-water'],
    'sanitation': ['toilet', 'hygiene'],
  };

  static List<int> encodeText(
    String text, {
    String? title,
    List<String>? keywords,
  }) {
    final vector = List<double>.filled(dimension, 0.0);

    final contentTokens = _tokenize(text);
    final titleTokens = _tokenize(title ?? '');
    final keywordTokens = (keywords ?? const <String>[])
        .map(_stem)
        .where((token) => token.isNotEmpty)
        .toList();

    _addTokenFeatures(vector, contentTokens, 1.0);
    _addTokenFeatures(vector, titleTokens, 1.35);
    _addTokenFeatures(vector, keywordTokens, 1.75);

    final combined = <String>[...contentTokens, ...titleTokens, ...keywordTokens];
    for (var index = 0; index < combined.length && index < 32; index++) {
      _addFeature(vector, 'pos:$index:${combined[index]}', 0.18);
    }

    final norm = _l2Norm(vector);
    if (norm == 0) {
      return List<int>.filled(dimension, 0);
    }

    final quantized = List<int>.filled(dimension, 0);
    for (var i = 0; i < vector.length; i++) {
      final scaled = ((vector[i] / norm) * 127.0).round();
      quantized[i] = scaled.clamp(-128, 127);
    }
    return quantized;
  }

  static List<String> _tokenize(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return const <String>[];
    final tokens = normalized
        .split(' ')
        .where((token) => token.isNotEmpty && !_stopwords.contains(token))
        .toList();
    return tokens;
  }

  static String _normalizeText(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  static String _stem(String token) {
    if (token.length <= 4) return token;
    for (final suffix in const ['ing', 'ed', 'es', 's']) {
      if (token.endsWith(suffix) && token.length - suffix.length >= 3) {
        return token.substring(0, token.length - suffix.length);
      }
    }
    return token;
  }

  static double _l2Norm(List<double> vector) {
    var total = 0.0;
    for (final value in vector) {
      total += value * value;
    }
    return math.sqrt(total);
  }

  static void _addTokenFeatures(
    List<double> vector,
    List<String> tokens,
    double baseWeight,
  ) {
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      if (token.isEmpty) continue;

      final base = _stem(token);
      _addFeature(vector, 'tok:$base', baseWeight);
      if (base != token) {
        _addFeature(vector, 'stem:$base', baseWeight * 0.85);
      }

      final synonymList = _synonyms[base];
      if (synonymList != null) {
        for (final synonym in synonymList) {
          _addFeature(vector, 'syn:$synonym', baseWeight * 0.7);
        }
      }

      for (final gram in _charTrigrams(base)) {
        _addFeature(vector, 'tri:$gram', baseWeight * 0.22);
      }

      if (index + 1 < tokens.length) {
        final bigram = '${base}_${_stem(tokens[index + 1])}';
        _addFeature(vector, 'bi:$bigram', baseWeight * 1.15);
      }
    }
  }

  static Iterable<String> _charTrigrams(String token) sync* {
    if (token.length < 3) return;
    for (var i = 0; i <= token.length - 3; i++) {
      yield token.substring(i, i + 3);
    }
  }

  static void _addFeature(List<double> vector, String feature, double weight) {
    final hash = _fnv1a32(utf8.encode(feature));
    final index = hash % dimension;
    final sign = (hash & 1) == 0 ? 1.0 : -1.0;
    vector[index] += weight * sign;
  }

  static int _fnv1a32(List<int> bytes) {
    var value = 0x811C9DC5;
    for (final byte in bytes) {
      value ^= byte;
      value = (value * 0x01000193) & 0xFFFFFFFF;
    }
    return value;
  }
}
