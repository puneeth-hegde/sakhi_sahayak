import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ModelManager {
  static const Map<String, String> models = {
    "whisper": "assets/models/whisper_tiny.bin",
    "llm": "assets/models/llama_1b_q4.gguf",
  };

  static Future<String> prepareModels() async {
    // IMPORTANT: matches Android context.filesDir
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory("${appDir.path}/models");

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // Model copying is now handled entirely by the native Android layer
    // to prevent Out-Of-Memory (OOM) crashes in the Dart VM.
    // See SakhiPlugin.kt and STTEngine.kt.

    return modelDir.path;
  }
}
