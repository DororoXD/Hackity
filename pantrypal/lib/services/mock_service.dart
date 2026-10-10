import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/alert_item.dart';
import '../models/batch_item.dart';
import '../models/import_result.dart';

/// Reads the sample JSON files in assets/mock/ so the app works without a server.
class MockService {
  static Future<Map<String, dynamic>> _load(String file) async {
    final text = await rootBundle.loadString('assets/mock/$file');
    return json.decode(text) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> _loadList(String file) async =>
      json.decode(await rootBundle.loadString('assets/mock/$file')) as List<dynamic>;

  static Future<String> today() async => (await _load('today.json'))['today'].toString();

  static Future<List<BatchItem>> batches() async => [
        for (final b in await _loadList('batches.json'))
          BatchItem.fromJson(Map<String, dynamic>.from(b as Map)),
      ];

  static Future<List<ProductItem>> products() async => [
        for (final p in await _loadList('products.json'))
          ProductItem.fromJson(Map<String, dynamic>.from(p as Map)),
      ];

  static Future<BatchItem> batchCreated() async =>
      BatchItem.fromJson(await _load('batch_created.json'));

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