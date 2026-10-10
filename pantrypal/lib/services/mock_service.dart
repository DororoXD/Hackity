import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/alert_item.dart';
import '../models/import_result.dart';

/// Reads the sample JSON files in assets/mock/ so the app works without a server.
class MockService {
  static Future<Map<String, dynamic>> _load(String file) async {
    final text = await rootBundle.loadString('assets/mock/$file');
    return json.decode(text) as Map<String, dynamic>;
  }

  static Future<AlertsResponse> alerts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AlertsResponse.fromJson(await _load('alerts.json'));
  }

  static Future<ImportResult> importSales({required bool dryRun}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final data = await _load('sales_import_sample.json');
    // A dry run saves nothing. A real import "saves" the OK rows.
    data['imported'] = dryRun ? 0 : data['ok'];
    return ImportResult.fromJson(data);
  }
}