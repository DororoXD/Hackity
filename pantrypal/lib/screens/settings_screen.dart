import 'package:flutter/material.dart';
import '../core/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _warn = '3 days';
  bool _push = true;
  bool _email = false;
  String _quiet = '22:00-07:00';
  String _sensitivity = 'Conservative';
  String _storage = 'Fridge';
  String _units = 'kg · MYR';

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
                'Settings',
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
              const _SectionTitle('ALERT RULES'),
              _Group(children: [
                _PickerRow(
                  label: 'Warn before spoilage',
                  value: _warn,
                  options: const ['1 day', '2 days', '3 days', '5 days', '7 days'],
                  onSelected: (v) => setState(() => _warn = v),
                ),
                _SwitchRow(
                  label: 'Push notifications',
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                ),
                _SwitchRow(
                  label: 'Email digest',
                  value: _email,
                  onChanged: (v) => setState(() => _email = v),
                ),
                _PickerRow(
                  label: 'Quiet hours',
                  value: _quiet,
                  options: const [
                    'Off',
                    '21:00-08:00',
                    '22:00-07:00',
                    '23:00-06:00',
                  ],
                  onSelected: (v) => setState(() => _quiet = v),
                ),
              ]),
              const SizedBox(height: 16),
              const _SectionTitle('PREDICTION'),
              _Group(children: [
                _PickerRow(
                  label: 'Sensitivity',
                  value: _sensitivity,
                  options: const ['Conservative', 'Balanced', 'Aggressive'],
                  onSelected: (v) => setState(() => _sensitivity = v),
                ),
                _PickerRow(
                  label: 'Default storage',
                  value: _storage,
                  options: const ['Fridge', 'Freezer', 'Ambient', 'Display'],
                  onSelected: (v) => setState(() => _storage = v),
                ),
                _LinkRow(
                  label: 'Shelf-life overrides',
                  onTap: () => _soon(context, 'Shelf-life overrides'),
                ),
              ]),
              const SizedBox(height: 16),
              const _SectionTitle('DATA'),
              _Group(children: [
                _LinkRow(
                  label: 'Units & currency',
                  value: _units,
                  onTap: () => _soon(context, 'Units & currency'),
                ),
                _LinkRow(
                  label: 'Categories & locations',
                  onTap: () => _soon(context, 'Categories & locations'),
                ),
                _LinkRow(
                  label: 'Export data',
                  onTap: () => _soon(context, 'Export data'),
                ),
              ]),
              const SizedBox(height: 16),
              const _SectionTitle('ACCOUNT'),
              _Group(children: [
                _LinkRow(
                  label: 'Profile & help',
                  onTap: () => _soon(context, 'Profile & help'),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

void _soon(BuildContext context, String name) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$name: coming soon')));
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
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

// A cream card holding several rows, with a thin divider between them.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.brown.withOpacity(0.15),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

const _rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
const _labelStyle = TextStyle(fontSize: 15, color: AppColors.brown);
const _valueStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: AppColors.brown,
);

class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _PickerRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    // Bottom-right corner of this row, in screen coordinates.
    final corner = box.localToGlobal(
      Offset(box.size.width, box.size.height),
      ancestor: overlay,
    );

    // A tiny rect at the right edge makes the menu open aligned to the right.
    final anchor = Rect.fromLTWH(corner.dx - 8, corner.dy, 1, 1);

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.cream,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      items: [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: Text(
              o,
              style: TextStyle(
                color: AppColors.brown,
                fontWeight: o == value ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
      ],
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openMenu(context),
      child: Padding(
        padding: _rowPadding,
        child: Row(
          children: [
            Expanded(child: Text(label, style: _labelStyle)),
            Text(value, style: _valueStyle),
            const Icon(Icons.arrow_drop_down, color: AppColors.brown),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _labelStyle)),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(AppColors.cream),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.brown
                  : AppColors.brown.withOpacity(0.25),
            ),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _LinkRow({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: _rowPadding,
        child: Row(
          children: [
            Expanded(child: Text(label, style: _labelStyle)),
            if (value != null) Text(value!, style: _valueStyle),
            const Icon(Icons.chevron_right, color: AppColors.brown),
          ],
        ),
      ),
    );
  }
}