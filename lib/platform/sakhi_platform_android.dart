import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'sakhi_platform.dart';

class SakhiPlatformAndroid extends SakhiPlatform {
  static const MethodChannel _channel = MethodChannel('com.sakhi/native');

  @override
  Future<bool> initialize() async {
    final res = await _channel.invokeMethod('initialize');
    return res ?? false;
  }

  @override
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    return await _channel.invokeMethod('transcribe', {
      'audioData': audioBytes,
      'sampleRate': 16000,
    });
  }

  @override
  Future<Map<String, dynamic>?> simplifyText(
    String text,
    Map<String, dynamic> prefs,
  ) async {
    return await _channel.invokeMapMethod('simplify', {
      'text': text,
      'preferences': prefs,
    });
  }

  @override
  Future<void> speakText(String text, double speed) async {
    await _channel.invokeMethod('speak', {'text': text, 'speed': speed});
  }
}
