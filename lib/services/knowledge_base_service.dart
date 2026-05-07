import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'knowledge_base_models.dart';

class KnowledgeBaseService {
  KnowledgeBaseService._();

  static const String _documentIndexAsset = 'assets/knowledge/documents/index.json';
  static const String _documentBaseAsset = 'assets/knowledge/documents/';
  static Future<List<String>>? _cachedDocumentAssets;
  static Future<List<KnowledgeDocument>>? _cachedDocuments;

  static Future<List<String>> listDocumentAssets() async {
    if (_cachedDocumentAssets != null) {
      return _cachedDocumentAssets!;
    }

    _cachedDocumentAssets = _loadDocumentAssets();
    return _cachedDocumentAssets!;
  }

  static Future<List<String>> _loadDocumentAssets() async {
    try {
      final indexJson = await rootBundle.loadString(_documentIndexAsset);
      final raw = jsonDecode(indexJson) as Map<String, dynamic>;
      final documents = raw['documents'] as List<dynamic>? ?? const [];
      return documents.map((value) => value.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<KnowledgeDocument> loadDocument(String assetPath) async {
    final resolvedAssetPath = assetPath.startsWith('assets/')
        ? assetPath
        : '$_documentBaseAsset$assetPath';
    final content = await rootBundle.loadString(resolvedAssetPath);
    return KnowledgeDocument.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
  }

  static Future<List<KnowledgeDocument>> loadAllDocuments() async {
    if (_cachedDocuments != null) {
      return _cachedDocuments!;
    }

    _cachedDocuments = _loadAllDocuments();
    return _cachedDocuments!;
  }

  static Future<List<KnowledgeDocument>> _loadAllDocuments() async {
    final assets = await listDocumentAssets();
    final documents = <KnowledgeDocument>[];

    for (final assetPath in assets) {
      try {
        documents.add(await loadDocument(assetPath));
      } catch (_) {
        // Skip invalid or missing assets for now.
      }
    }

    return documents;
  }
}
