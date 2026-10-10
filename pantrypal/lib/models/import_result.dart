/// One row from POST /sales/import.
class ImportRow {
  final int row;
  final String? saleDate;
  final String product; // the text from the file
  final String? name; // the catalogue name, if matched
  final double? quantity;
  final String status; // ok / unmatched / bad_date / bad_quantity

  const ImportRow({
    required this.row,
    required this.saleDate,
    required this.product,
    required this.name,
    required this.quantity,
    required this.status,
  });

  factory ImportRow.fromJson(Map<String, dynamic> j) => ImportRow(
        row: (j['row'] as num?)?.toInt() ?? 0,
        saleDate: j['sale_date']?.toString(),
        product: j['product']?.toString() ?? '',
        name: j['name']?.toString(),
        quantity: (j['quantity'] as num?)?.toDouble(),
        status: j['status']?.toString() ?? '',
      );
}

/// The whole POST /sales/import response.
class ImportResult {
  final List<ImportRow> rows;
  final int ok;
  final int unmatched;
  final int errors;
  final int imported;

  const ImportResult({
    required this.rows,
    required this.ok,
    required this.unmatched,
    required this.errors,
    required this.imported,
  });

  int get skipped => rows.length - ok;

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        rows: [
          for (final r in (j['rows'] as List? ?? []))
            ImportRow.fromJson(r as Map<String, dynamic>),
        ],
        ok: (j['ok'] as num?)?.toInt() ?? 0,
        unmatched: (j['unmatched'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        imported: (j['imported'] as num?)?.toInt() ?? 0,
      );
}