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
    print("Windows: initialize()");

    // Load whisper_bridge.dll via FFI
    _whisper = WhisperFFI();

    // ---- FIXED ABSOLUTE PATHS ----

    // 1) Correct whisper.dll location
    final whisperDll = File("windows/sakhi_native/whisper.dll").absolute.path;

    // 2) Correct model location (your chosen real folder)
    final modelPath = File(
      "windows/sakhi_native/models/whisper_tiny_q8.bin",
    ).absolute.path;

    print("Windows: Whisper DLL → $whisperDll");
    print("Windows: Whisper model → $modelPath");

    // Initialize whisper engine
    _ready = await _whisper.initialize(whisperDll, modelPath);

    print("Windows: Whisper initialized? → $_ready");

    return _ready;
  }

  @override
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    print("Windows: transcribeAudio() called");

    if (!_ready) {
      print("Windows ERROR: Whisper not initialized");
      return null;
    }

    // Save WAV to temp
    final tmp = await getTemporaryDirectory();
    final wavPath = File("${tmp.path}/input.wav").absolute.path;

    print("Windows: Saving WAV → $wavPath");

    await File(wavPath).writeAsBytes(audioBytes);

    print("Windows: Running Whisper transcription...");

    final result = await _whisper.transcribe(wavPath);

    print("Windows: Whisper result → $result");

    return result;
  }

  @override
  Future<Map<String, dynamic>?> simplifyText(
    String text,
    Map<String, dynamic> prefs,
  ) async {
    print("Windows: simplifyText() called");

    return {
      "steps": [
        {"id": 1, "text": "You said: $text"},
        {"id": 2, "text": "(LLaMA simplification coming next)"},
      ],
    };
  }

  @override
  Future<void> speakText(String text, double speed) async {
    print("Windows: speakText() called (not implemented)");
  }
}
