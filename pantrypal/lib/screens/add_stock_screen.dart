import 'package:flutter/material.dart';
import '../core/theme.dart';

const _units = ['units', 'kg', 'g', 'L', 'packs'];
const _storages = ['Fridge', 'Freezer', 'Ambient', 'Display'];
const _quickDays = [3, 7, 14, 30];

// Placeholder shelf-life guesses. Replace with the ML model's prediction later.
const _sampleShelfLifeDays = {
  'Fridge': 6,
  'Freezer': 90,
  'Ambient': 3,
  'Display': 2,
};

const _infoBg = Color(0xFFDDEBD6);
const _infoText = Color(0xFF2F6B45);

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _product = TextEditingController();
  final _quantity = TextEditingController(text: '12');
  final _supplier = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();

  String _unit = 'units';
  String _storage = 'Fridge';
  DateTime _received = DateTime.now();
  DateTime? _expiry;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _supplier.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) => d == null
      ? 'dd/mm/yyyy'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate({required bool isExpiry}) async {
    final initial = isExpiry ? (_expiry ?? _received) : _received;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isExpiry ? _expiry = picked : _received = picked);
  }

  void _save({required bool addAnother}) {
    if (_product.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a product name first')),
      );
      return;
    }
    // TODO: send the new batch to your provider / API here.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${_product.text.trim()}')),
    );
    setState(() {
      _product.clear();
      _quantity.text = '12';
      _expiry = null;
      _received = DateTime.now();
      _supplier.clear();
      _cost.clear();
      _notes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shelfLife = _sampleShelfLifeDays[_storage]!;
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
                'Add Stock',
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
        // Form
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  _BigButton('Scan barcode', filled: true, onTap: () {}),
                  const SizedBox(width: 10),
                  _BigButton('Use last entry', onTap: () {}),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Product'),
              _field(controller: _product, hint: 'Start typing, e.g. Fresh Milk 1L'),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Quantity'),
                        _field(
                          controller: _quantity,
                          keyboard: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Unit'),
                        DropdownButtonFormField<String>(
                          value: _unit,
                          dropdownColor: AppColors.cream,
                          decoration: _decoration(null),
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.brown),
                          items: [
                            for (final u in _units)
                              DropdownMenuItem(value: u, child: Text(u)),
                          ],
                          onChanged: (v) => setState(() => _unit = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Received'),
                        _DateBox(
                          text: _fmt(_received),
                          isSet: true,
                          onTap: () => _pickDate(isExpiry: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Expiry date'),
                        _DateBox(
                          text: _fmt(_expiry),
                          isSet: _expiry != null,
                          onTap: () => _pickDate(isExpiry: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in _quickDays)
                    _Chip(
                      '+${d}d',
                      selected: false,
                      onTap: () => setState(
                          () => _expiry = _received.add(Duration(days: d))),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const _Label('Storage'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _storages)
                    _Chip(
                      s,
                      selected: s == _storage,
                      onTap: () => setState(() => _storage = s),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      'More details (supplier, cost, notes)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.brown.withOpacity(0.8),
                      ),
                    ),
                    iconColor: AppColors.brown,
                    collapsedIconColor: AppColors.brown,
                    childrenPadding:
                        const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      _field(controller: _supplier, hint: 'Supplier'),
                      const SizedBox(height: 8),
                      _field(
                        controller: _cost,
                        hint: 'Cost (RM)',
                        keyboard: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      _field(controller: _notes, hint: 'Notes', lines: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: _infoText),
                    children: [
                      const TextSpan(text: 'Predicted shelf life: '),
                      TextSpan(
                        text: '$shelfLife days',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: _expiry == null
                            ? ' in $_storage. Add the expiry date to improve accuracy.'
                            : ' in $_storage.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _BigButton('Save',
                      filled: true, onTap: () => _save(addAnother: false)),
                  const SizedBox(width: 10),
                  _BigButton('Save & add another',
                      onTap: () => _save(addAnother: true)),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _decoration(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.brown.withOpacity(0.45)),
        filled: true,
        fillColor: AppColors.cream,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboard,
    int lines = 1,
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        style: const TextStyle(fontSize: 15, color: AppColors.brown),
        decoration: _decoration(hint),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
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

class _DateBox extends StatelessWidget {
  final String text;
  final bool isSet;
  final VoidCallback onTap;
  const _DateBox(
      {required this.text, required this.isSet, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSet
                        ? AppColors.brown
                        : AppColors.brown.withOpacity(0.45),
                  ),
                ),
              ),
              const Icon(Icons.calendar_today_outlined,
                  size: 18, color: AppColors.brown),
            ],
          ),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class _BigButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _BigButton(this.label, {this.filled = false, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 46,
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
        ),
      );
}
