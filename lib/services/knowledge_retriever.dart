import 'dart:math';

import 'knowledge_base_models.dart';
import 'knowledge_base_service.dart';
import 'embedding_service.dart';

class KnowledgeSearchHit {
  final KnowledgeDocument document;
  final KnowledgeChunk chunk;
  final double score;

  const KnowledgeSearchHit({
    required this.document,
    required this.chunk,
    required this.score,
  });
}

class KnowledgeRetriever {
  static Future<List<KnowledgeSearchHit>> search(
    String query, {
    int topK = 5,
    List<int>? queryEmbedding,
    double keywordThreshold = 6.5,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final documents = await KnowledgeBaseService.loadAllDocuments();
    final queryTokens = _tokenize(normalizedQuery);
    final hits = <KnowledgeSearchHit>[];

    for (final document in documents) {
      for (final chunk in document.chunks) {
        final score = _scoreChunk(
          queryTokens: queryTokens,
          queryText: normalizedQuery,
          document: document,
          chunk: chunk,
        );
        if (score > 0) {
          hits.add(
            KnowledgeSearchHit(
              document: document,
              chunk: chunk,
              score: score,
            ),
          );
        }
      }
    }

    hits.sort((left, right) => right.score.compareTo(left.score));

    // If keyword high-confidence result exists, return keyword hits (fast-path)
    if (hits.isNotEmpty && hits.first.score >= keywordThreshold) {
      if (hits.length > topK) return hits.sublist(0, topK);
      return hits;
    }

    // Keyword path didn't reach confidence threshold. If a query embedding is provided,
    // use the vector fallback (semantic search) via EmbeddingService.
    final embeddingService = EmbeddingService();
    final ok = await embeddingService.initialize();
    if (ok && embeddingService.isInitialized) {
      final vectorResults = queryEmbedding != null
          ? await embeddingService.search(
              queryEmbedding,
              topK: topK,
            )
          : await embeddingService.searchText(query, topK: topK);

      if (vectorResults.isNotEmpty) {
        // Map chunk IDs to KnowledgeDocument/KnowledgeChunk
        final documents = await KnowledgeBaseService.loadAllDocuments();
        final Map<String, Map<String, dynamic>> chunkMap = {};
        for (final doc in documents) {
          for (final ch in doc.chunks) {
            chunkMap[ch.id] = {
              'document': doc,
              'chunk': ch,
            };
          }
        }

        final List<KnowledgeSearchHit> semanticHits = [];
        for (final vr in vectorResults) {
          final entry = chunkMap[vr.chunkId];
          if (entry != null) {
            semanticHits.add(KnowledgeSearchHit(
              document: entry['document'] as KnowledgeDocument,
              chunk: entry['chunk'] as KnowledgeChunk,
              score: vr.similarity,
            ));
          }
        }

        semanticHits.sort((a, b) => b.score.compareTo(a.score));
        return semanticHits;
      }
    }

    // No vector fallback available or no confident vectors — return keyword hits (may be empty)
    if (hits.length > topK) {
      return hits.sublist(0, topK);
    }
    return hits;
  }

  static double _scoreChunk({
    required Set<String> queryTokens,
    required String queryText,
    required KnowledgeDocument document,
    required KnowledgeChunk chunk,
  }) {
    final textTokens = _tokenize(chunk.text);
    final keywordTokens = chunk.keywords.map(_normalize).toSet();
    final documentTokens = {
      ..._tokenize(document.document.title),
      ..._tokenize(document.document.category),
      ..._tokenize(document.document.language),
    };

    var score = 0.0;

    for (final token in queryTokens) {
      if (keywordTokens.contains(token)) {
        score += 5;
      }
      if (textTokens.contains(token)) {
        score += 2;
      }
      if (documentTokens.contains(token)) {
        score += 1.5;
      }
    }

    if (_normalize(chunk.text).contains(queryText)) {
      score += 8;
    }

    if (_normalize(document.document.title).contains(queryText)) {
      score += 6;
    }

    if (document.document.trustLevel.toLowerCase() == 'verified') {
      score += 1;
    }

    if (document.document.category.toLowerCase() == 'health') {
      score += 0.5;
    }

    return score;
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Set<String> _tokenize(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return <String>{};
    }
    return normalized.split(' ').where((token) => token.isNotEmpty).toSet();
  }
}
