import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../core/theme.dart';
import '../models/import_result.dart';
import '../services/api_service.dart';
import '../widgets/app_popups.dart';

const _green = Color(0xFF3F8A5A);
const _steps = ['1 Upload', '2 Map', '3 Preview', '4 Done'];
const _maxRowsShown = 50;

class SalesImportScreen extends StatefulWidget {
  const SalesImportScreen({super.key});

  @override
  State<SalesImportScreen> createState() => _SalesImportScreenState();
}

class _SalesImportScreenState extends State<SalesImportScreen> {
  // 0 = Upload, 2 = Preview, 3 = Done (1 = Map is not needed yet)
  int _step = 0;
  bool _busy = false;
  String? _error;
  String? _fileName;
  List<int>? _bytes;
  ImportResult? _result;

  // Imports done in this session. A saved history needs a backend endpoint.
  final List<(String, String)> _history = [];

  Future<void> _pickFile() async {
    if (_busy) return;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      if (files == null || files.isEmpty) return; // the user cancelled

      final file = files.first;
      final bytes = await file.readAsBytes();
      setState(() {
        _fileName = file.name;
        _bytes = bytes;
        _result = null;
        _error = null;
        _busy = true;
      });

      // Preview step: check the file without saving anything.
      final result = await ApiService.importSales(
        filename: file.name,
        bytes: bytes,
        dryRun: true,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = 2;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _import() async {
    final result = _result;
    final bytes = _bytes;
    final name = _fileName;
    if (result == null || bytes == null || name == null || _busy) return;

    if (result.ok == 0) {
      showAppSnack(context, 'There are no valid rows to import');
      return;
    }

    final confirmed = await confirmDialog(
      context,
      title: 'Import valid rows?',
      message: '${result.ok} row(s) will be imported. '
          '${result.skipped} row(s) will be skipped.',
      confirmLabel: 'Import',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final done = await ApiService.importSales(
        filename: name,
        bytes: bytes,
        dryRun: false,
      );
      if (!mounted) return;
      setState(() {
        _result = done;
        _step = 3;
        _busy = false;
        _history.insert(0, (name, '${done.imported} rows imported'));
      });
      showAppSnack(context, '${done.imported} rows imported');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          color: AppColors.brown,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Import',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.peach,
                ),
              ),
              Text(
                'Upload your POS export',
                style: TextStyle(fontSize: 13, color: AppColors.cream),
              ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _StepTabs(current: _step),
              const SizedBox(height: 14),
              _UploadZone(
                fileName: _fileName,
                busy: _busy,
                onChoose: _pickFile,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.red),
                ),
              ],
              const SizedBox(height: 18),
              const _SectionTitle('PREVIEW & VALIDATE'),
              _PreviewCard(
                result: _result,
                done: _step == 3,
                busy: _busy,
                onImport: _import,
              ),
              const SizedBox(height: 18),
              const _SectionTitle('IMPORT HISTORY'),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Imports you make appear here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.brown.withOpacity(0.7),
                    ),
                  ),
                ),
              for (final h in _history) ...[
                GestureDetector(
                  onTap: () => showInfoSheet(
                    context,
                    title: h.$1,
                    subtitle: 'Import details',
                    rows: [('File', h.$1), ('Result', h.$2)],
                  ),
                  child: _HistoryCard(file: h.$1, info: h.$2),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.brown,
        ),
      ),
    );
  }
}

class _StepTabs extends StatelessWidget {
  final int current;
  const _StepTabs({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Text(
                  _steps[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: i == current
                        ? AppColors.brown
                        : AppColors.brown.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.navActive
                        : AppColors.brown.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _UploadZone extends StatelessWidget {
  final String? fileName;
  final bool busy;
  final VoidCallback onChoose;

  const _UploadZone({
    required this.fileName,
    required this.busy,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(AppColors.brown.withOpacity(0.5)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            if (busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AppColors.brown),
              )
            else
              const Icon(Icons.arrow_upward, size: 30, color: AppColors.brown),
            const SizedBox(height: 8),
            Text(
              busy
                  ? 'Checking file…'
                  : (fileName ?? 'Drop a CSV or Excel file here'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.brown),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PillButton('Choose file', filled: true, onTap: onChoose),
                const SizedBox(width: 10),
                _PillButton('Download template',
                    onTap: () => showTemplateSheet(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _PillButton(this.label, {this.filled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.brown : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.brown),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? AppColors.cream : AppColors.brown,
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => old.color != color;
}

// Turns the server's status text into a label and colour.
(String, Color) _statusInfo(String status) {
  switch (status) {
    case 'ok':
      return ('OK', _green);
    case 'unmatched':
      return ('Unmatched', AppColors.orange);
    case 'bad_date':
      return ('Bad date', AppColors.red);
    case 'bad_quantity':
      return ('Bad quantity', AppColors.red);
    default:
      final text = status.replaceAll('_', ' ');
      final label = text.isEmpty
          ? 'Unknown'
          : '${text[0].toUpperCase()}${text.substring(1)}';
      return (label, AppColors.red);
  }
}

class _PreviewCard extends StatelessWidget {
  final ImportResult? result;
  final bool done;
  final bool busy;
  final VoidCallback onImport;

  const _PreviewCard({
    required this.result,
    required this.done,
    required this.busy,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: r == null ? _empty() : _filled(r),
    );
  }

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Choose a file to check it here. Nothing is saved until you press '
          '"Import valid rows".',
          style: TextStyle(fontSize: 13, color: AppColors.brown),
        ),
      );

  Widget _filled(ImportResult r) {
    const head = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.brown,
    );
    const cell = TextStyle(fontSize: 13, color: AppColors.brown);

    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: w);

    final shown = r.rows.take(_maxRowsShown).toList();
    final hidden = r.rows.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.1),
            1: FlexColumnWidth(1.9),
            2: FlexColumnWidth(0.7),
            3: FlexColumnWidth(1.5),
          },
          border: TableBorder(
            horizontalInside:
                BorderSide(color: AppColors.brown.withOpacity(0.2)),
          ),
          children: [
            TableRow(children: [
              pad(const Text('Date', style: head)),
              pad(const Text('Product', style: head)),
              pad(const Text('Qty', style: head)),
              pad(const Text('Status', style: head)),
            ]),
            for (final row in shown)
              TableRow(children: [
                pad(Text(formatShortDate(row.saleDate), style: cell)),
                pad(Text(row.name ?? row.product, style: cell)),
                pad(Text(
                  row.quantity == null ? '—' : formatQty(row.quantity!),
                  style: cell,
                )),
                pad(Text(
                  _statusInfo(row.status).$1,
                  style: cell.copyWith(
                    color: _statusInfo(row.status).$2,
                    fontWeight: FontWeight.w600,
                  ),
                )),
              ]),
          ],
        ),
        if (hidden > 0) ...[
          const SizedBox(height: 6),
          Text(
            'and $hidden more rows',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${r.ok} OK · ${r.unmatched} unmatched · '
          '${r.errors} ${r.errors == 1 ? 'error' : 'errors'}',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.brown.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: done ? null : onImport,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done || busy
                  ? AppColors.brown.withOpacity(0.45)
                  : AppColors.brown,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              done ? 'Imported ${r.imported} rows' : 'Import valid rows',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.cream,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String file;
  final String info;
  const _HistoryCard({required this.file, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.brown.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}