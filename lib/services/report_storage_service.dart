import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReportStorageService {
  ReportStorageService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _reportsKey = 'offline_reports_secure_v1';

  static Future<List<Map<String, dynamic>>> loadReports() async {
    final raw = await _storage.read(key: _reportsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      // Fall through to empty list if storage is corrupt.
    }

    return <Map<String, dynamic>>[];
  }

  static Future<void> saveReport(Map<String, dynamic> report) async {
    final reports = await loadReports();
    reports.add(report);
    await _storage.write(key: _reportsKey, value: jsonEncode(reports));
  }
}