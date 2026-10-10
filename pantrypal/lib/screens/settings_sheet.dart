import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'app_popups.dart';

Future<void> shelfLifeOverridesSheet(BuildContext context) {
  // Sample products. Replace with your real product list later.
  final days = <String, int>{
    'Fresh milk': 7,
    'Strawberries': 3,
    'Chicken breast': 2,
    'Leafy vegetables': 3,
  };
  return showAppSheet<void>(
    context,
    title: 'Shelf-life overrides',
    subtitle: 'Set your own shelf life (in days) when you know better than the prediction.',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in days.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.brown),
                    ),
                  ),
                  QuantityStepper(
                    compact: true,
                    value: e.value,
                    min: 1,
                    max: 365,
                    onChanged: (v) => setState(() => days[e.key] = v),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Save overrides',
            filled: true,
            onTap: () {
              Navigator.pop(ctx);
              showAppSnack(context, 'Shelf-life overrides saved');
            },
          ),
        ],
      ),
    ),
  );
}

Future<String?> unitsCurrencySheet(BuildContext context,
    {required String current}) {
  final parts = current.split(' · ');
  var weight = parts.first;
  var currency = parts.length > 1 ? parts[1] : 'MYR';
  return showAppSheet<String>(
    context,
    title: 'Units & currency',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeading('Weight unit'),
          Wrap(
            spacing: 8,
            children: [
              for (final w in const ['kg', 'lb'])
                PillChoice(
                  label: w,
                  selected: w == weight,
                  onTap: () => setState(() => weight = w),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SheetHeading('Currency'),
          Wrap(
            spacing: 8,
            children: [
              for (final c in const ['MYR', 'SGD', 'USD'])
                PillChoice(
                  label: c,
                  selected: c == currency,
                  onTap: () => setState(() => currency = c),
                ),
            ],
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Save',
            filled: true,
            onTap: () => Navigator.pop(ctx, '$weight · $currency'),
          ),
        ],
      ),
    ),
  );
}

Future<void> categoriesSheet(BuildContext context) {
  final categories = ['Dairy', 'Produce', 'Meat', 'Bakery'];
  final locations = ['Fridge 1', 'Fridge 2', 'Freezer', 'Display'];

  Widget chips(List<String> list, void Function(void Function()) setState) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in list)
          Chip(
            label: Text(item),
            labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.brown),
            backgroundColor: Colors.transparent,
            side: const BorderSide(color: AppColors.brown),
            deleteIconColor: AppColors.brown,
            onDeleted: () => setState(() => list.remove(item)),
          ),
      ],
    );
  }

  return showAppSheet<void>(
    context,
    title: 'Categories & locations',
    subtitle: 'Used for filters on the Stock tab and when adding stock.',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHeading('Categories'),
          chips(categories, setState),
          _AddField(
            hint: 'Add a category',
            onAdd: (v) => setState(() => categories.add(v)),
          ),
          const SizedBox(height: 16),
          const SheetHeading('Locations'),
          chips(locations, setState),
          _AddField(
            hint: 'Add a location',
            onAdd: (v) => setState(() => locations.add(v)),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Done',
            filled: true,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

class _AddField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onAdd;
  const _AddField({required this.hint, required this.onAdd});

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    widget.onAdd(v);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _c,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 14, color: AppColors.brown),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle:
                    TextStyle(color: AppColors.brown.withOpacity(0.45)),
                filled: true,
                fillColor: AppColors.peach.withOpacity(0.35),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: AppButton(label: 'Add', onTap: _submit),
          ),
        ],
      ),
    );
  }
}

Future<void> exportSheet(BuildContext context) async {
  final choice = await showAppSheet<String>(
    context,
    title: 'Export data',
    subtitle: 'Choose what to export.',
    builder: (ctx) => Column(
      children: [
        OptionRow(
          label: 'Stock batches',
          subtitle: 'CSV file',
          icon: Icons.inventory_2_outlined,
          onTap: () => Navigator.pop(ctx, 'Stock batches (CSV)'),
        ),
        OptionRow(
          label: 'Waste log',
          subtitle: 'CSV file',
          icon: Icons.delete_outline,
          onTap: () => Navigator.pop(ctx, 'Waste log (CSV)'),
        ),
        OptionRow(
          label: 'Weekly report',
          subtitle: 'Excel file',
          icon: Icons.table_chart_outlined,
          onTap: () => Navigator.pop(ctx, 'Weekly report (Excel)'),
        ),
      ],
    ),
  );
  if (choice != null && context.mounted) {
    showAppSnack(context, 'Export requested: $choice');
  }
}

Future<void> helpSheet(BuildContext context) {
  const faqs = [
    (
      'How is shelf life predicted?',
      'PantryPal starts from the printed expiry date, then adjusts it for your storage temperature and how fast the item usually sells.'
    ),
    (
      'What does "At risk" mean?',
      'The batch is likely to still be unsold when it expires, so it needs action today, such as a discount.'
    ),
    (
      'How do I import sales?',
      'Open the Sales tab, upload a CSV or Excel export from your POS, check the preview, then import the valid rows.'
    ),
  ];
  return showAppSheet<void>(
    context,
    title: 'Help & FAQ',
    builder: (ctx) => Theme(
      data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
      child: Column(
        children: [
          for (final f in faqs)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              iconColor: AppColors.brown,
              collapsedIconColor: AppColors.brown,
              title: Text(
                f.$1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brown,
                ),
              ),
              expandedAlignment: Alignment.centerLeft,
              children: [
                Text(
                  f.$2,
                  style: const TextStyle(fontSize: 14, color: AppColors.brown),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

Future<void> profileHelpSheet(BuildContext context) async {
  final action = await showAppSheet<String>(
    context,
    title: 'Profile & help',
    builder: (ctx) => Column(
      children: [
        OptionRow(
          label: 'Edit profile',
          subtitle: 'Change your display name',
          icon: Icons.person_outline,
          onTap: () => Navigator.pop(ctx, 'profile'),
        ),
        OptionRow(
          label: 'Help & FAQ',
          icon: Icons.help_outline,
          onTap: () => Navigator.pop(ctx, 'help'),
        ),
        OptionRow(
          label: 'About PantryPal',
          icon: Icons.info_outline,
          onTap: () => Navigator.pop(ctx, 'about'),
        ),
        OptionRow(
          label: 'Log out',
          icon: Icons.logout,
          onTap: () => Navigator.pop(ctx, 'logout'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;

  if (action == 'profile') {
    final name = await textInputDialog(
      context,
      title: 'Edit profile',
      initial: 'User',
      hint: 'Display name',
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      showAppSnack(context, 'Name updated to $name');
    }
  } else if (action == 'help') {
    await helpSheet(context);
  } else if (action == 'about') {
    await showInfoSheet(
      context,
      title: 'About PantryPal',
      subtitle: 'Tells you what to discount, sell first or order less.',
      rows: const [
        ('Version', '1.0.0 (prototype)'),
        ('Predictions', 'Illustrative'),
      ],
    );
  } else if (action == 'logout') {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to see your alerts.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (ok && context.mounted) showAppSnack(context, 'Logged out (demo)');
  }
}