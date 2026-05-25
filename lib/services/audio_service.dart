import 'dart:typed_data';
import 'package:flutter/services.dart';

class AudioService {
  static const MethodChannel _channel = MethodChannel("com.sakhi.whisper");

  Future<void> startRecording() async {
    try {
      await _channel.invokeMethod("startNativeRecording");
    } catch (e) {
      print("Error starting recording: $e");
    }
  }

  Future<Uint8List> stopRecording() async {
    try {
      final dynamic result = await _channel.invokeMethod(
        "stopNativeRecording",
      );
      if (result == null) return Uint8List(0);
      return result as Uint8List;
    } catch (e) {
      print("Error stopping recording: $e");
      return Uint8List(0);
    }
  }
}
