import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ModelManager {
  static const Map<String, String> models = {
    "whisper": "assets/models/whisper_tiny_q8.bin",
    "llm": "assets/models/llama_1b_q4.gguf",
  };

  static Future<String> prepareModels() async {
    // IMPORTANT: matches Android context.filesDir
    final appDir = await getApplicationSupportDirectory();
    final modelDir = Directory("${appDir.path}/models");

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    for (var entry in models.entries) {
      final source = entry.value;
      final fileName = source.split('/').last;
      final target = File("${modelDir.path}/$fileName");

      if (!await target.exists()) {
        final byteData = await rootBundle.load(source);
        await target.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      }
    }

    return modelDir.path;
  }
}
