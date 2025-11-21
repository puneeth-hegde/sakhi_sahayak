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
      final Uint8List bytes = await _channel.invokeMethod(
        "stopNativeRecording",
      );
      return bytes;
    } catch (e) {
      print("Error stopping recording: $e");
      return Uint8List(0);
    }
  }
}
