// lib/services/audio_service.dart
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _ready = false;
  String? _pcmPath;

  /// Initialize recorder + permission
  Future<void> initialize() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception("Microphone permission denied");
    }

    if (!_ready) {
      await _recorder.openRecorder();
      _ready = true;
    }
  }

  Future<void> _ensureReady() async {
    if (!_ready) await initialize();
  }

  /// Start recording RAW PCM16 — no WAV header
  Future<void> startRecording() async {
    await _ensureReady();

    final dir = await getTemporaryDirectory();
    _pcmPath = "${dir.path}/recording.pcm";

    final file = File(_pcmPath!);
    if (await file.exists()) await file.delete();

    await _recorder.startRecorder(
      toFile: _pcmPath,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  /// Stop and return bytes
  Future<Uint8List> stopRecording() async {
    if (!_ready) return Uint8List(0);

    await _recorder.stopRecorder();

    if (_pcmPath == null) return Uint8List(0);

    final file = File(_pcmPath!);
    if (!await file.exists()) return Uint8List(0);

    return file.readAsBytes();
  }
}
