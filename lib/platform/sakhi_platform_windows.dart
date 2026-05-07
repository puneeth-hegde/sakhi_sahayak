import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'sakhi_platform.dart';
import 'whisper_ffi.dart';

class SakhiPlatformWindows extends SakhiPlatform {
  late WhisperFFI _whisper;
  bool _ready = false;

  @override
  Future<bool> initialize() async {
    // Load whisper_bridge.dll via FFI
    _whisper = WhisperFFI();

    // Correct whisper.dll location
    final whisperDll = File("windows/sakhi_native/whisper.dll").absolute.path;

    // Correct model location
    final modelPath = File(
      "windows/sakhi_native/models/whisper_tiny_q8.bin",
    ).absolute.path;

    // Initialize whisper engine
    _ready = await _whisper.initialize(whisperDll, modelPath);

    return _ready;
  }

  @override
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    if (!_ready) {
      return null;
    }

    // Save WAV to temp
    final tmp = await getTemporaryDirectory();
    final wavPath = File("${tmp.path}/input.wav").absolute.path;

    await File(wavPath).writeAsBytes(audioBytes);

    final result = await _whisper.transcribe(wavPath);

    return result;
  }

  @override
  Future<Map<String, dynamic>?> simplifyText(
    String text,
    Map<String, dynamic> prefs,
  ) async {
    // TODO: Phase 1 - Implement Windows LLM simplification
    return {
      "steps": [
        {"id": 1, "text": "You said: $text"},
        {"id": 2, "text": "(LLM simplification not yet implemented for Windows)"},
      ],
    };
  }

  @override
  Future<void> speakText(String text, double speed) async {
    // TODO: Windows TTS implementation pending
  }
}
