import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../core/theme.dart';
import '../models/batch_item.dart';
import '../services/api_service.dart';
import '../widgets/app_popups.dart';

enum _Level { atRisk, useSoon, fresh }

const _green = Color(0xFF4F9D69);

/// What the Stock screen shows, loaded together from the backend.
class _StockData {
  final String today;
  final List<BatchItem> batches; // active only, soonest to expire first
  final Map<int, ProductItem> products;
  const _StockData(this.today, this.batches, this.products);
}

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late Future<_StockData> _future = _load();
  String _filter = 'All';
  String _query = '';
  int? _selectedId;

  static Future<_StockData> _load() async {
    final today = ApiService.fetchToday();
    final batches = ApiService.fetchBatches();
    final products = ApiService.fetchProducts();
    return _StockData(
      await today,
      await batches,
      {for (final p in await products) p.productId: p},
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  List<BatchItem> _visible(_StockData data) {
    final q = _query.toLowerCase();
    return data.batches.where((b) {
      final matchesFilter = switch (_filter) {
        'All' => true,
        'At risk' => _level(b) != _Level.fresh,
        _ => data.products[b.productId]?.category == _filter,
      };
      final matchesSearch = q.isEmpty ||
          b.name.toLowerCase().contains(q) ||
          '#${b.id}'.contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StockData>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data;
        return Column(
          children: [
            _Header(date: data == null ? '' : formatLongDate(data.today)),
            Expanded(child: _body(context, snap)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, AsyncSnapshot<_StockData> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brown));
    }
    if (snap.hasError) {
      return _Message(text: snap.error.toString(), onRetry: _reload);
    }
    final data = snap.data!;
    final categories = {
      for (final b in data.batches) data.products[b.productId]?.category ?? ''
    }.where((c) => c.isNotEmpty).toList()
      ..sort();
    final filters = ['All', 'At risk', ...categories];
    final visible = _visible(data);
    final selected = visible.where((b) => b.id == _selectedId).firstOrNull ??
        visible.firstOrNull;

    return RefreshIndicator(
      color: AppColors.brown,
      onRefresh: () async {
        _reload();
        await _future.catchError((_) => data);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppColors.brown),
            decoration: InputDecoration(
              hintText: 'Search products or batches',
              hintStyle: TextStyle(color: AppColors.brown.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: AppColors.brown),
              filled: true,
              fillColor: AppColors.cream,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _FilterChip(
                label: filters[i],
                selected: filters[i] == _filter,
                onTap: () => setState(() => _filter = filters[i]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${data.batches.length} active batches · sorted by soonest to expire',
            style: TextStyle(
                fontSize: 12, color: AppColors.brown.withOpacity(0.7)),
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  data.batches.isEmpty
                      ? 'No stock yet. Add a batch with the + button.'
                      : 'No batches match',
                  style: const TextStyle(color: AppColors.brown),
                ),
              ),
            ),
          // Tap a batch to open its detail card right below it.
          for (final b in visible) ...[
            _BatchCard(
              batch: b,
              product: data.products[b.productId],
              level: _level(b),
              selected: b.id == selected?.id,
              onTap: () => setState(() => _selectedId = b.id),
            ),
            if (b.id == selected?.id) ...[
              const SizedBox(height: 6),
              _DetailCard(
                batch: b,
                onEditQuantity: () => _editQuantity(b),
                onLogWaste: () => _logWaste(b),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  _Level _level(BatchItem b) => b.daysLeft <= 0
      ? _Level.atRisk
      : b.daysLeft <= 2
          ? _Level.useSoon
          : _Level.fresh;

  Future<void> _editQuantity(BatchItem b) async {
    final text = await textInputDialog(
      context,
      title: 'Edit quantity',
      initial: formatQty(b.quantity),
      hint: 'Quantity left (${b.unit})',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
    if (text == null || !mounted) return;
    final qty = double.tryParse(text.replaceAll(',', '.'));
    if (qty == null || qty < 0) {
      showAppSnack(context, 'Enter a number of ${b.unit}, 0 or more');
      return;
    }
    await _patch(b, quantity: qty,
        done: qty == 0
            ? '${b.name} marked as sold out'
            : '${b.name}: ${formatQty(qty)} ${b.unit} left');
  }

  Future<void> _logWaste(BatchItem b) async {
    final units = math.max(1, b.quantity.round());
    final r = await wasteSheet(
      context,
      title: 'Log waste',
      product: '${b.name} · ${formatQty(b.quantity)} ${b.unit} left',
      max: units,
      confirmLabel: 'Log waste',
    );
    if (r == null || !mounted) return;
    if (r.qty >= units) {
      await _patch(b, status: 'discarded',
          done: 'Whole batch of ${b.name} logged as waste (${r.reason})');
    } else {
      final left = double.parse(math.max(0.0, b.quantity - r.qty).toStringAsFixed(1));
      await _patch(b, quantity: left,
          done: '${r.qty} ${b.unit} of ${b.name} logged as waste (${r.reason})');
    }
  }

  Future<void> _patch(BatchItem b,
      {double? quantity, String? status, required String done}) async {
    try {
      await ApiService.updateBatch(b.id, quantity: quantity, status: status);
      if (!mounted) return;
      showAppSnack(context, done);
      _reload();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }
}

class _Header extends StatelessWidget {
  final String date;
  const _Header({required this.date});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.brown,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock / Batches',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.peach,
              ),
            ),
            Text(date,
                style: const TextStyle(fontSize: 13, color: AppColors.cream)),
          ],
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
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

class _BatchCard extends StatelessWidget {
  final BatchItem batch;
  final ProductItem? product;
  final _Level level;
  final bool selected;
  final VoidCallback onTap;

  const _BatchCard({
    required this.batch,
    required this.product,
    required this.level,
    required this.selected,
    required this.onTap,
  });

  Color get _color => switch (level) {
        _Level.atRisk => AppColors.red,
        _Level.useSoon => AppColors.orange,
        _Level.fresh => _green,
      };

  String get _label => switch (level) {
        _Level.atRisk => batch.daysLeft < 0 ? 'Expired' : 'Last day',
        _Level.useSoon => 'Use soon',
        _Level.fresh => 'Fresh',
      };

  // Share of shelf life left, counting today as a sellable day.
  double get _shelfLeft {
    final life = product?.shelfLifeDays ?? 0;
    if (life <= 0) return 0;
    return ((batch.daysLeft + 1) / life).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 11, color: AppColors.brown);
    final left = batch.daysLeft < 0
        ? 'Expired ${-batch.daysLeft} day(s) ago'
        : batch.daysLeft == 0
            ? 'Last day to sell: today'
            : '${batch.daysLeft} day(s) left';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brown : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown,
                    ),
                  ),
                ),
                if (batch.discountPct > 0) ...[
                  Text('${batch.discountPct}% off',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brown)),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Batch #${batch.id} · received ${formatShortDate(batch.receivedDate)}'
              ' · ${formatQty(batch.quantity)} ${batch.unit} left',
              style: small,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _shelfLeft,
                minHeight: 6,
                color: _color,
                backgroundColor: AppColors.brown.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sell by: ${formatShortDate(batch.expiryDate)}',
                    style: small),
                Text(left, style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final BatchItem batch;
  final VoidCallback onEditQuantity;
  final VoidCallback onLogWaste;
  const _DetailCard({
    required this.batch,
    required this.onEditQuantity,
    required this.onLogWaste,
  });

  @override
  Widget build(BuildContext context) {
    final discount =
        batch.discountPct > 0 ? ' · ${batch.discountPct}% discount on' : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${batch.name} · Batch #${batch.id}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Received ${formatShortDate(batch.receivedDate)} · '
            '${formatQty(batch.quantity)} ${batch.unit} left · '
            'last sellable day ${formatShortDate(batch.expiryDate)}$discount',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _OutlineButton('Edit quantity', onTap: onEditQuantity),
              const SizedBox(width: 8),
              _OutlineButton('Log waste', onTap: onLogWaste),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Message({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 44, color: AppColors.brown),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.brown)),
              const SizedBox(height: 16),
              Row(children: [_OutlineButton('Try again', onTap: onRetry)]),
            ],
          ),
        ),
      );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brown),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}
