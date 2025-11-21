import 'package:flutter_test/flutter_test.dart';
import 'package:sakhi_sahayak/services/intent_detector.dart';

void main() {
  final detector = IntentDetector();

  test('Detects assist intent (English)', () async {
    final result = await detector.detectIntent(
      "My child has fever what should I do",
    );

    expect(result.intent, IntentType.assist);
    expect(result.confidence, greaterThan(0.1));
  });

  test('Detects report intent (English)', () async {
    final result = await detector.detectIntent(
      "Someone followed me and touched me",
    );

    expect(result.intent, IntentType.report);
    expect(result.confidence, greaterThan(0.5));
  });

  test('Detects assist intent (Hindi)', () async {
    final result = await detector.detectIntent("mujhe kaise madad milegi");

    expect(result.intent, IntentType.assist);
  });
}
