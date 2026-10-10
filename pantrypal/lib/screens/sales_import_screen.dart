import 'package:flutter/material.dart';
import '../core/theme.dart';

const _green = Color(0xFF3F8A5A);
const _steps = ['1 Upload', '2 Map', '3 Preview', '4 Done'];

// Sample data from the design. Replace with real import results later.
const _previewRows = [
  ('09 Oct', 'Fresh Milk 1L', '14', 'OK'),
  ('09 Oct', 'Strawbery 250g', '6', 'Unmatched'),
  ('32 Oct', 'Greek Yogurt', '9', 'Bad date'),
];

const _history = [
  ('sales_week40.csv', '4 Oct · 312 rows'),
  ('sales_week39.csv', '27 Sep · 298 rows'),
];

class SalesImportScreen extends StatelessWidget {
  const SalesImportScreen({super.key});

  // Which step is highlighted. 0 = Upload, 1 = Map, 2 = Preview, 3 = Done.
  static const int currentStep = 0;

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
                'Sat 10 Oct',
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
              const _StepTabs(current: currentStep),
              const SizedBox(height: 14),
              const _UploadZone(),
              const SizedBox(height: 18),
              const _SectionTitle('PREVIEW & VALIDATE (STEP 3)'),
              const _PreviewCard(),
              const SizedBox(height: 18),
              const _SectionTitle('IMPORT HISTORY'),
              for (final h in _history) ...[
                _HistoryCard(file: h.$1, info: h.$2),
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
  const _UploadZone();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(AppColors.brown.withOpacity(0.5)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            const Icon(Icons.arrow_upward, size: 30, color: AppColors.brown),
            const SizedBox(height: 8),
            const Text(
              'Drop a CSV or Excel file here',
              style: TextStyle(fontSize: 14, color: AppColors.brown),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PillButton('Choose file', filled: true, onTap: () {
                  // TODO: open the file picker (add the file_picker package).
                }),
                const SizedBox(width: 10),
                _PillButton('Download template', onTap: () {}),
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  Color _statusColor(String s) => switch (s) {
        'OK' => _green,
        'Unmatched' => AppColors.orange,
        _ => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.brown,
    );
    const cell = TextStyle(fontSize: 13, color: AppColors.brown);

    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: w);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(0.7),
              3: FlexColumnWidth(1.4),
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
              for (final r in _previewRows)
                TableRow(children: [
                  pad(Text(r.$1, style: cell)),
                  pad(Text(r.$2, style: cell)),
                  pad(Text(r.$3, style: cell)),
                  pad(Text(
                    r.$4,
                    style: cell.copyWith(
                      color: _statusColor(r.$4),
                      fontWeight: FontWeight.w600,
                    ),
                  )),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1 OK · 1 unmatched · 1 error',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brown,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Import valid rows',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cream,
                ),
              ),
            ),
          ),
        ],
      ),
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
