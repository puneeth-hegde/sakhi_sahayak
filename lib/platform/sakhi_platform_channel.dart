import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'sakhi_platform.dart';

class SakhiMethodChannel extends SakhiPlatform {
  static const MethodChannel _channel = MethodChannel("com.sakhi.whisper");

  @override
  Future<bool> initialize() async {
    final ok = await _channel.invokeMethod("loadModel");
    return ok == true;
  }

  @override
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    return await _channel.invokeMethod("transcribeAudio", audioBytes);
  }

  @override
  Future<Map<String, dynamic>?> simplifyText(
    String text,
    Map<String, dynamic> prefs,
  ) async {
    final result = await _channel.invokeMethod("simplify", {
      "text": text,
      "prefs": prefs,
    });
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  @override
  Future<void> speakText(String text, double speed) async {
    await _channel.invokeMethod("speak", {"text": text, "speed": speed});
  }
}
