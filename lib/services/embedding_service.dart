import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'knowledge_base_models.dart';
import 'offline_semantic_encoder.dart';

/// Embedding Service for vector-based semantic search.
/// Uses deterministic offline semantic embeddings (int8 quantized).
class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();

  factory EmbeddingService() {
    return _instance;
  }

  EmbeddingService._internal();

  List<VectorChunk>? _vectorIndex;
  bool _initialized = false;
  final String _vectorIndexPath = 'assets/knowledge/vectors.json';

  /// Initializes embedding service by loading precomputed vector index
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      final String vectorJson = await rootBundle.loadString(_vectorIndexPath);
      final dynamic data = await Future.delayed(
        const Duration(milliseconds: 100),
        () => _parseVectors(vectorJson),
      );

      if (data is List<VectorChunk>) {
        _vectorIndex = data;
        _initialized = true;
        return true;
      }
    } catch (e) {
      print('Error loading vector index: $e');
    }
    return false;
  }

  /// Parse vector JSON and return list of VectorChunk
  List<VectorChunk> _parseVectors(String jsonString) {
    try {
      final Map<String, dynamic> parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<dynamic> chunksJson = parsed['chunks'] ?? [];
      final List<VectorChunk> chunks = chunksJson
          .map((e) => VectorChunk.fromJson(e as Map<String, dynamic>))
          .toList();
      return chunks;
    } catch (e) {
      print('Vector parse error: $e');
      return <VectorChunk>[];
    }
  }

  /// Check if embeddings are loaded
  bool get isInitialized => _initialized && _vectorIndex != null && _vectorIndex!.isNotEmpty;

  /// Get total number of embedded chunks
  int get embeddedChunkCount => _vectorIndex?.length ?? 0;

  /// Encode raw text into the same offline semantic vector space used by vectors.json.
  List<int> encodeText(
    String text, {
    String? title,
    List<String>? keywords,
  }) {
    return OfflineSemanticEncoder.encodeText(
      text,
      title: title,
      keywords: keywords,
    );
  }

  /// Return a sample stored vector (first vector) for debug use or null if none
  List<int>? getSampleVector() {
    if (_vectorIndex == null || _vectorIndex!.isEmpty) return null;
    return _vectorIndex!.first.vector;
  }

  /// Compute cosine similarity between two vectors (int8 quantized)
  /// Vectors are stored as int8 (-128 to 127), need dequantization
  double _cosineSimilarity(List<int> vec1, List<int> vec2) {
    if (vec1.length != vec2.length) return 0.0;

    // Dequantize int8 vectors to float
    var dequant1 = vec1.map((v) => v / 127.0).toList();
    var dequant2 = vec2.map((v) => v / 127.0).toList();

    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (int i = 0; i < dequant1.length; i++) {
      dotProduct += dequant1[i] * dequant2[i];
      norm1 += dequant1[i] * dequant1[i];
      norm2 += dequant2[i] * dequant2[i];
    }

    norm1 = sqrt(norm1);
    norm2 = sqrt(norm2);

    if (norm1 == 0 || norm2 == 0) return 0.0;
    return dotProduct / (norm1 * norm2);
  }

  /// Search embeddings for query (returns similarity scores only)
  /// This is stubbed until vectors.json is generated
  /// Phase 2.3: Connect to actual vector search after embedding generation
  Future<List<VectorSearchResult>> search(
    List<int> queryEmbedding, {
    int topK = 5,
    double similarityThreshold = 0.3,
  }) async {
    if (!isInitialized || _vectorIndex == null) {
      return [];
    }

    final results = <VectorSearchResult>[];

    // Compute similarity to all stored vectors
    for (var i = 0; i < _vectorIndex!.length; i++) {
      final chunk = _vectorIndex![i];
      final similarity = _cosineSimilarity(queryEmbedding, chunk.vector);

      if (similarity >= similarityThreshold) {
        results.add(
          VectorSearchResult(
            chunkId: chunk.chunkId,
            document: chunk.document,
            title: chunk.title,
            similarity: similarity,
            index: i,
          ),
        );
      }
    }

    // Sort by similarity descending
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    // Return top K
    return results.take(topK).toList();
  }

  /// Search using raw text; the encoder will create the query embedding offline.
  Future<List<VectorSearchResult>> searchText(
    String query, {
    int topK = 5,
    double similarityThreshold = 0.3,
  }) async {
    final queryEmbedding = encodeText(query);
    return search(
      queryEmbedding,
      topK: topK,
      similarityThreshold: similarityThreshold,
    );
  }

  /// Clear embeddings (for testing or low-memory devices)
  void dispose() {
    _vectorIndex = null;
    _initialized = false;
  }
}

/// Represents a single embedding in the vector index
class VectorChunk {
  final String chunkId;
  final String document;
  final String title;
  final List<int> vector; // int8 quantized

  VectorChunk({
    required this.chunkId,
    required this.document,
    required this.title,
    required this.vector,
  });

  factory VectorChunk.fromJson(Map<String, dynamic> json) {
    return VectorChunk(
      chunkId: json['chunk_id'] as String,
      document: json['document'] as String,
      title: json['title'] as String,
      vector: List<int>.from(json['vector'] as List),
    );
  }
}

/// Result from vector similarity search
class VectorSearchResult {
  final String chunkId;
  final String document;
  final String title;
  final double similarity; // 0.0 to 1.0
  final int index; // Index in _vectorIndex for debugging

  VectorSearchResult({
    required this.chunkId,
    required this.document,
    required this.title,
    required this.similarity,
    required this.index,
  });

  @override
  String toString() {
    return 'VectorSearchResult(chunk_id: $chunkId, doc: $document, similarity: ${(similarity * 100).toStringAsFixed(1)}%)';
  }
}
