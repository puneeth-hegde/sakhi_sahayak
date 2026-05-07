import 'dart:convert';

import 'embedding_service.dart';

/// Simple debug helper to validate EmbeddingService inside the Flutter app.
/// Call `EmbeddingDebug.runSanityCheck()` from a debug route or during startup (debug only).
class EmbeddingDebug {
  static Future<void> runSanityCheck() async {
    final svc = EmbeddingService();
    final ok = await svc.initialize();
    if (!ok || !svc.isInitialized) {
      print('EmbeddingDebug: service failed to initialize');
      return;
    }

    if (svc.embeddedChunkCount == 0) {
      print('EmbeddingDebug: no embedded chunks loaded');
      return;
    }

    // Use first stored vector as the query to validate search returns itself
    final firstVector = svc.getSampleVector();
    if (firstVector == null) {
      print('EmbeddingDebug: no sample vector available');
      return;
    }
    final results = await svc.search(
      firstVector,
      topK: 5,
      similarityThreshold: 0.0,
    );
    print('EmbeddingDebug: found ${results.length} results');
    for (final r in results) {
      print(r.toString());
    }
  }
}
