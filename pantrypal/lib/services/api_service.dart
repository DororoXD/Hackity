import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/alert_item.dart';
import '../models/import_result.dart';
import 'mock_service.dart';

/// A readable error that screens can show to the user.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  /// GET /alerts
  static Future<AlertsResponse> fetchAlerts() async {
    if (ApiConfig.useMock) return MockService.alerts();

    final res = await _send(
      () => http.get(Uri.parse('${ApiConfig.baseUrl}/alerts')),
    );
    return AlertsResponse.fromJson(_decode(res));
  }

  /// PATCH /batches/{id}  with status: sold_out | discarded
  static Future<void> updateBatch(int batchId, String status) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return;
    }
    final res = await _send(() => http.patch(
          Uri.parse('${ApiConfig.baseUrl}/batches/$batchId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': status}),
        ));
    _decode(res);
  }

  /// POST /sales/import?dry_run=true|false  (CSV or Excel file upload)
  ///
  /// dryRun = true  -> only checks the file (the Preview step)
  /// dryRun = false -> checks and saves the valid rows
  static Future<ImportResult> importSales({
    required String filename,
    required List<int> bytes,
    required bool dryRun,
  }) async {
    if (ApiConfig.useMock) return MockService.importSales(dryRun: dryRun);

    final uri = Uri.parse('${ApiConfig.baseUrl}/sales/import')
        .replace(queryParameters: {'dry_run': dryRun.toString()});

    final res = await _send(() async {
      final request = http.MultipartRequest('POST', uri)
        // "file" is the field name on the /docs page. Change it if the
        // backend uses a different name.
        ..files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: filename));
      return http.Response.fromStream(await request.send());
    });
    return ImportResult.fromJson(_decode(res));
  }

  /// GET /sales/imports
  static Future<List<ImportHistoryItem>> fetchImportHistory() async {
    if (ApiConfig.useMock) return const [];
    final res = await _send(
      () => http.get(Uri.parse('${ApiConfig.baseUrl}/sales/imports')),
    );
    if (res.statusCode != 200) {
      _decode(res);
    }
    dynamic body;
    try {
      body = json.decode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw const ApiException('The server sent a response the app could not read.');
    }
    // Accept either a plain list or {"imports": [...]}.
    final Object? raw =
        body is List ? body : (body is Map ? (body['imports'] ?? body['items']) : null);
    final items = <ImportHistoryItem>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(ImportHistoryItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return items;
  }

  // Runs a request and turns any network problem into a readable message.
  static Future<http.Response> _send(
      Future<http.Response> Function() call) async {
    try {
      return await call().timeout(ApiConfig.timeout);
    } catch (_) {
      throw const ApiException(
        'Could not reach the server. Check that it is running, that you are '
        'on the same Wi-Fi, and that the address in constants.dart is correct.',
      );
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    dynamic body;
    try {
      body = json.decode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (res.statusCode != 200) {
      final detail = body is Map ? body['detail'] : null;
      throw ApiException(
        detail != null
            ? detail.toString()
            : 'The server returned an error (${res.statusCode}).',
      );
    }
    if (body is! Map<String, dynamic>) {
      throw const ApiException('The server sent a response the app could not read.');
    }
    return body;
  }
}