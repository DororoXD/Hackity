import 'package:flutter/material.dart';
import '../core/theme.dart';

// =====================================================================
// Small building blocks used inside the pop-ups
// =====================================================================

class AppButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool destructive;
  final VoidCallback? onTap;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = !filled
        ? Colors.transparent
        : (destructive ? AppColors.red : AppColors.brown);
    final fg = !filled
        ? AppColors.brown
        : (destructive ? Colors.white : AppColors.cream);
    final border = filled && destructive ? AppColors.red : AppColors.brown;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class PillChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PillChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brown : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.brown),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.cream : AppColors.brown,
          ),
        ),
      ),
    );
  }
}

class SheetHeading extends StatelessWidget {
  final String text;
  const SheetHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.brown,
          ),
        ),
      );
}

class OptionRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onTap;

  const OptionRow({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.brown),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brown,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.brown.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.brown),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.brown.withOpacity(0.12)),
      ],
    );
  }
}

class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool compact;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 44.0;
    final gap = compact ? 12.0 : 24.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIcon(
          icon: Icons.remove,
          size: size,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: gap),
        Text(
          '$value',
          style: TextStyle(
            fontSize: compact ? 18 : 32,
            fontWeight: FontWeight.w700,
            color: AppColors.brown,
          ),
        ),
        SizedBox(width: gap),
        _RoundIcon(
          icon: Icons.add,
          size: size,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  const _RoundIcon({required this.icon, required this.size, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.3 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brown),
          ),
          child: Icon(icon, size: size * 0.5, color: AppColors.brown),
        ),
      ),
    );
  }
}

// =====================================================================
// Pop-up shells: bottom sheet, dialog and snackbar
// =====================================================================

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.cream)),
        backgroundColor: AppColors.brown,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brown.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.brown,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.brown.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 14),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.cream,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 10),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

// =====================================================================
// Reusable pop-ups
// =====================================================================

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(
    context,
    title: title,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.brown),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                filled: true,
                destructive: destructive,
                onTap: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<int?> quantityDialog(
  BuildContext context, {
  required String title,
  String? hint,
  required int initial,
  required int max,
  int min = 0,
}) {
  var value = initial;
  return showAppDialog<int>(
    context,
    title: title,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null) ...[
            Text(
              hint,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.brown.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: QuantityStepper(
              value: value,
              min: min,
              max: max,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Save',
                  filled: true,
                  onTap: () => Navigator.pop(ctx, value),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirmLabel = 'Save',
  Widget? header,
  TextInputType? keyboard,
}) {
  return showAppDialog<String>(
    context,
    title: title,
    builder: (ctx) => _TextInputBody(
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      header: header,
      keyboard: keyboard,
    ),
  );
}

class _TextInputBody extends StatefulWidget {
  final String initial;
  final String? hint;
  final String confirmLabel;
  final Widget? header;
  final TextInputType? keyboard;

  const _TextInputBody({
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.header,
    required this.keyboard,
  });

  @override
  State<_TextInputBody> createState() => _TextInputBodyState();
}

class _TextInputBodyState extends State<_TextInputBody> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null) ...[
          widget.header!,
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _c,
          keyboardType: widget.keyboard,
          style: const TextStyle(fontSize: 15, color: AppColors.brown),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: AppColors.brown.withOpacity(0.45)),
            filled: true,
            fillColor: AppColors.peach.withOpacity(0.35),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: widget.confirmLabel,
                filled: true,
                onTap: () => Navigator.pop(context, _c.text.trim()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<int?> discountSheet(BuildContext context,
    {required String product, int initial = 20}) {
  var pct = initial;
  final options = {10, 20, 30, 50, if (initial > 0) initial}.toList()..sort();
  return showAppSheet<int>(
    context,
    title: 'Apply discount',
    subtitle: product,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeading('Discount amount'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in options)
                PillChoice(
                  label: '$p%',
                  selected: pct == p,
                  onTap: () => setState(() => pct = p),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A bigger discount clears stock faster but earns less per unit.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Apply $pct% discount',
            filled: true,
            onTap: () => Navigator.pop(ctx, pct),
          ),
        ],
      ),
    ),
  );
}

Future<({int qty, String reason})?> wasteSheet(
  BuildContext context, {
  required String title,
  required String product,
  required int max,
  String confirmLabel = 'Confirm',
  List<String> reasons = const ['Expired', 'Spoiled early', 'Damaged', 'Other'],
}) {
  var qty = max;
  var reason = reasons.first;
  return showAppSheet<({int qty, String reason})>(
    context,
    title: title,
    subtitle: product,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeading('How many units?'),
          Center(
            child: QuantityStepper(
              value: qty,
              min: 1,
              max: max,
              onChanged: (v) => setState(() => qty = v),
            ),
          ),
          const SizedBox(height: 18),
          const SheetHeading('Reason'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in reasons)
                PillChoice(
                  label: r,
                  selected: r == reason,
                  onTap: () => setState(() => reason = r),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            label: confirmLabel,
            filled: true,
            destructive: true,
            onTap: () => Navigator.pop(ctx, (qty: qty, reason: reason)),
          ),
        ],
      ),
    ),
  );
}

Future<String?> snoozeSheet(BuildContext context, {required String product}) {
  return showAppSheet<String>(
    context,
    title: 'Snooze alert',
    subtitle: product,
    builder: (ctx) => Column(
      children: [
        for (final o in const ['Remind me tomorrow', 'In 2 days', 'In 3 days'])
          OptionRow(
            label: o,
            icon: Icons.snooze,
            onTap: () => Navigator.pop(ctx, o),
          ),
      ],
    ),
  );
}

Future<int?> pickFromListSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<(String, String)> items,
}) {
  return showAppSheet<int>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (ctx) => Column(
      children: [
        for (var i = 0; i < items.length; i++)
          OptionRow(
            label: items[i].$1,
            subtitle: items[i].$2,
            onTap: () => Navigator.pop(ctx, i),
          ),
      ],
    ),
  );
}

Future<void> showInfoSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<(String, String)> rows,
}) {
  return showAppSheet<void>(
    context,
    title: title,
    subtitle: subtitle,
    builder: (ctx) => Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.$1,
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.brown.withOpacity(0.7))),
                Text(r.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown,
                    )),
              ],
            ),
          ),
        const SizedBox(height: 12),
        AppButton(label: 'Close', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

Future<void> showAlertDetailSheet(
  BuildContext context, {
  required String title,
  required String details,
  required String why,
  required String recommendation,
  String? saving,
}) {
  return showAppSheet<void>(
    context,
    title: title,
    subtitle: details,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetHeading('Why this alert'),
        Text(why,
            style: const TextStyle(fontSize: 14, color: AppColors.brown)),
        const SizedBox(height: 16),
        const SheetHeading('Recommended action'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.peach.withOpacity(0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recommendation,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.brown)),
              if (saving != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Expected saving: $saving',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(label: 'Close', onTap: () => Navigator.pop(ctx)),
      ],
    ),
  );
}

Future<String?> barcodeDialog(BuildContext context) {
  return textInputDialog(
    context,
    title: 'Scan barcode',
    hint: 'Type the barcode number',
    confirmLabel: 'Use code',
    keyboard: TextInputType.number,
    header: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.brown,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.qr_code_scanner,
              size: 48, color: AppColors.cream),
        ),
        const SizedBox(height: 8),
        Text(
          'Camera scanning is not connected yet. Type the number instead.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.brown.withOpacity(0.7),
          ),
        ),
      ],
    ),
  );
}

Future<void> showTemplateSheet(BuildContext context) async {
  final choice = await showAppSheet<String>(
    context,
    title: 'Download template',
    subtitle: 'Use this layout so your columns import cleanly.',
    builder: (ctx) => Column(
      children: [
        OptionRow(
          label: 'CSV template',
          subtitle: 'Columns: Date, Product, Qty',
          icon: Icons.description_outlined,
          onTap: () => Navigator.pop(ctx, 'CSV'),
        ),
        OptionRow(
          label: 'Excel template',
          subtitle: 'Columns: Date, Product, Qty',
          icon: Icons.table_chart_outlined,
          onTap: () => Navigator.pop(ctx, 'Excel'),
        ),
      ],
    ),
  );
  if (choice != null && context.mounted) {
    showAppSnack(context, '$choice template requested');
  }
}

// =====================================================================
// Full flows: pop-up first, then a confirmation message
// (replace the snackbar with a provider / API call later)
// =====================================================================

Future<void> discountFlow(BuildContext context, String product) async {
  final pct = await discountSheet(context, product: product);
  if (pct != null && context.mounted) {
    showAppSnack(context, '$pct% discount applied to $product');
  }
}

/// Returns the quantity marked as used, or null if cancelled.
Future<int?> markUsedFlow(
    BuildContext context, String product, int units) async {
  final qty = await quantityDialog(
    context,
    title: 'Mark as used',
    hint: product,
    initial: units,
    max: units,
    min: 1,
  );
  if (qty != null && context.mounted) {
    showAppSnack(context, '$qty units of $product marked as used');
  }
  return qty;
}

/// Returns the quantity discarded, or null if cancelled.
Future<int?> discardFlow(
    BuildContext context, String product, int units) async {
  final r = await wasteSheet(
    context,
    title: 'Discard stock',
    product: product,
    max: units,
    confirmLabel: 'Discard',
  );
  if (r != null && context.mounted) {
    showAppSnack(context, 'Discarded ${r.qty} × $product (${r.reason})');
  }
  return r?.qty;
}

Future<void> moveToColdFlow(BuildContext context, String product) async {
  final ok = await confirmDialog(
    context,
    title: 'Move to cold storage?',
    message:
        '$product will be moved to the fridge and its predicted shelf life will be recalculated.',
    confirmLabel: 'Move',
  );
  if (ok && context.mounted) {
    showAppSnack(context, '$product moved to cold storage');
  }
}

Future<void> snoozeFlow(BuildContext context, String product) async {
  final choice = await snoozeSheet(context, product: product);
  if (choice != null && context.mounted) {
    showAppSnack(context, 'Snoozed: ${choice.toLowerCase()}');
  }
}