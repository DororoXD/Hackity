import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../core/theme.dart';
import '../models/batch_item.dart';
import '../services/api_service.dart';
import '../widgets/app_popups.dart';

const _quickDays = [3, 7, 14, 30];
const _infoBg = Color(0xFFDDEBD6);
const _infoText = Color(0xFF2F6B45);

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  // Kept while the app runs, for "Use last entry".
  static ({ProductItem product, double quantity})? _lastEntry;

  late final Future<(String, List<ProductItem>)> _future = _load();
  final _quantity = TextEditingController(text: '10');
  List<ProductItem> _products = const [];
  ProductItem? _product;
  DateTime? _today; // the server's date, not the phone's
  DateTime? _received;
  DateTime? _expiry; // null = received + the product's shelf life
  bool _saving = false;

  static Future<(String, List<ProductItem>)> _load() async {
    final today = ApiService.fetchToday();
    final products = ApiService.fetchProducts();
    return (await today, await products);
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) => d == null
      ? 'dd/mm/yyyy'
      : '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Last sellable day if the user does not pick one: the arrival day counts as day 1.
  DateTime? get _defaultExpiry => (_received == null || _product == null)
      ? null
      : _received!.add(Duration(days: _product!.shelfLifeDays - 1));

  Future<void> _pickDate({required bool isExpiry}) async {
    final base = _received ?? _today ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? (_expiry ?? _defaultExpiry ?? base) : base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiry = picked;
      } else {
        _received = picked;
      }
    });
  }

  Future<void> _chooseProduct() async {
    if (_products.isEmpty) return;
    final i = await pickFromListSheet(
      context,
      title: 'Choose product',
      subtitle: 'From the product catalogue',
      items: [
        for (final p in _products)
          (p.name, '${p.category} · ${p.unit} · keeps ${p.shelfLifeDays} days'),
      ],
    );
    if (i != null) setState(() => _product = _products[i]);
  }

  Future<void> _scanBarcode() async {
    final code = await barcodeDialog(context);
    if (code == null || code.isEmpty || !mounted) return;
    final id = int.tryParse(code);
    final match = _products.where((p) =>
        p.productId == id || p.name.toLowerCase() == code.toLowerCase());
    if (match.isEmpty) {
      showAppSnack(context, 'No product with code $code. Try a catalogue number, e.g. 41.');
      return;
    }
    setState(() => _product = match.first);
  }

  void _useLastEntry() {
    final last = _lastEntry;
    if (last == null) {
      showAppSnack(context, 'Nothing saved yet. Save a batch first.');
      return;
    }
    setState(() {
      _product = last.product;
      _quantity.text = formatQty(last.quantity);
    });
  }

  Future<void> _save({required bool addAnother}) async {
    final product = _product;
    final qty = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (product == null) {
      showAppSnack(context, 'Choose a product first');
      return;
    }
    if (qty == null || qty <= 0) {
      showAppSnack(context, 'Enter a quantity above 0');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final batch = await ApiService.createBatch(
        productId: product.productId,
        quantity: qty,
        receivedDate: _received == null ? null : _iso(_received!),
        expiryDate: _expiry == null ? null : _iso(_expiry!),
      );
      _lastEntry = (product: product, quantity: qty);
      if (!mounted) return;
      showAppSnack(
          context,
          'Saved ${formatQty(batch.quantity)} ${batch.unit} ${batch.name} '
          '(batch #${batch.id}), sell by ${formatShortDate(batch.expiryDate)}');
      setState(() {
        _saving = false;
        _expiry = null;
        if (!addAnother) {
          _product = null;
          _quantity.text = '10';
          _received = _today;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, List<ProductItem>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasData && _today == null) {
          _today = DateTime.tryParse(snap.data!.$1);
          _received ??= _today;
          _products = snap.data!.$2;
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.brown,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Stock',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.peach,
                    ),
                  ),
                  Text(
                    snap.hasData ? formatLongDate(snap.data!.$1) : '',
                    style: const TextStyle(fontSize: 13, color: AppColors.cream),
                  ),
                ],
              ),
            ),
            Expanded(
              child: snap.hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(snap.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.brown)),
                      ),
                    )
                  : !snap.hasData
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.brown))
                      : _form(context),
            ),
          ],
        );
      },
    );
  }

  Widget _form(BuildContext context) {
    final product = _product;
    final expiry = _expiry ?? _defaultExpiry;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _BigButton('Scan barcode', filled: true, onTap: _scanBarcode),
            const SizedBox(width: 10),
            _BigButton('Use last entry', onTap: _useLastEntry),
          ],
        ),
        const SizedBox(height: 14),
        const _Label('Product'),
        GestureDetector(
          onTap: _chooseProduct,
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
                    product == null
                        ? 'Tap to choose, e.g. Tomatoes'
                        : '${product.name} · ${product.category}',
                    style: TextStyle(
                      fontSize: 15,
                      color: product == null
                          ? AppColors.brown.withOpacity(0.45)
                          : AppColors.brown,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: AppColors.brown),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Label('Quantity${product == null ? '' : ' (${product.unit})'}'),
        _field(
          controller: _quantity,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
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
                  const _Label('Last sellable day'),
                  _DateBox(
                    text: _fmt(expiry),
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
                onTap: () => setState(() => _expiry =
                    (_received ?? _today ?? DateTime.now()).add(Duration(days: d))),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _infoBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            product == null
                ? 'Choose a product to see its shelf life.'
                : '${product.name} keeps ${product.shelfLifeDays} days'
                    '${_expiry == null ? ', so the last sellable day is set for you. Change it if the label says otherwise.' : '. You set the last sellable day yourself.'}',
            style: const TextStyle(fontSize: 13, color: _infoText),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _BigButton(_saving ? 'Saving…' : 'Save',
                filled: true, onTap: () => _save(addAnother: false)),
            const SizedBox(width: 10),
            _BigButton('Save & add another',
                onTap: () => _save(addAnother: true)),
          ],
        ),
        const SizedBox(height: 8),
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
  }) =>
      TextField(
        controller: controller,
        keyboardType: keyboard,
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
