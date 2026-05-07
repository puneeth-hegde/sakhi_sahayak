import 'dart:convert';

class KnowledgeDocumentMeta {
  final String id;
  final String title;
  final String category;
  final String source;
  final String jurisdiction;
  final String lastUpdated;
  final String version;
  final String trustLevel;
  final String language;

  const KnowledgeDocumentMeta({
    required this.id,
    required this.title,
    required this.category,
    required this.source,
    required this.jurisdiction,
    required this.lastUpdated,
    required this.version,
    required this.trustLevel,
    required this.language,
  });

  factory KnowledgeDocumentMeta.fromJson(Map<String, dynamic> json) {
    return KnowledgeDocumentMeta(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      source: json['source'] as String,
      jurisdiction: json['jurisdiction'] as String,
      lastUpdated: json['last_updated'] as String,
      version: json['version'] as String,
      trustLevel: json['trust_level'] as String,
      language: json['language'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'source': source,
        'jurisdiction': jurisdiction,
        'last_updated': lastUpdated,
        'version': version,
        'trust_level': trustLevel,
        'language': language,
      };
}

class KnowledgeChunk {
  final String id;
  final int sequenceOrder;
  final String text;
  final List<String> keywords;
  final String language;

  const KnowledgeChunk({
    required this.id,
    required this.sequenceOrder,
    required this.text,
    required this.keywords,
    required this.language,
  });

  factory KnowledgeChunk.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'] as List<dynamic>? ?? const [];
    return KnowledgeChunk(
      id: json['id'] as String,
      sequenceOrder: json['sequence_order'] as int,
      text: json['text'] as String,
      keywords: rawKeywords.map((value) => value.toString()).toList(),
      language: json['language'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence_order': sequenceOrder,
        'text': text,
        'keywords': keywords,
        'language': language,
      };
}

class KnowledgeDocument {
  final KnowledgeDocumentMeta document;
  final List<KnowledgeChunk> chunks;

  const KnowledgeDocument({required this.document, required this.chunks});

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) {
    final chunksJson = json['chunks'] as List<dynamic>? ?? const [];
    return KnowledgeDocument(
      document: KnowledgeDocumentMeta.fromJson(
        Map<String, dynamic>.from(json['document'] as Map),
      ),
      chunks: chunksJson
          .map((value) => KnowledgeChunk.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'document': document.toJson(),
        'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
