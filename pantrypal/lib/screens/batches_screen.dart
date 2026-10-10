import 'package:flutter/material.dart';
import '../core/theme.dart';

enum BatchStatus { atRisk, useSoon, fresh }

class _Batch {
  final String name;
  final String id;
  final String received;
  final int left;
  final String category;
  final BatchStatus status;
  final double shelfLeft; // 0.0 to 1.0, share of shelf life remaining
  final String printed;
  final String predicted;
  final String timeline;

  const _Batch({
    required this.name,
    required this.id,
    required this.received,
    required this.left,
    required this.category,
    required this.status,
    required this.shelfLeft,
    required this.printed,
    required this.predicted,
    required this.timeline,
  });
}

// Sample data from the design. Replace with data from your provider later.
const _batches = [
  _Batch(
    name: 'Fresh Milk 1L',
    id: '#B-2041',
    received: '6 Oct',
    left: 12,
    category: 'Dairy',
    status: BatchStatus.atRisk,
    shelfLeft: 0.08,
    printed: '10 Oct',
    predicted: '10 Oct',
    timeline: '6 Oct Received 12 units · 10 Oct Alert raised: expires today',
  ),
  _Batch(
    name: 'Strawberries 250g',
    id: '#B-2038',
    received: '8 Oct',
    left: 20,
    category: 'Produce',
    status: BatchStatus.useSoon,
    shelfLeft: 0.35,
    printed: '13 Oct',
    predicted: '12 Oct',
    timeline: '8 Oct Received 24 units · 9 Oct Sold 4 · '
        '10 Oct Alert raised: temp above ideal',
  ),
  _Batch(
    name: 'Greek Yogurt 500g',
    id: '#B-2044',
    received: '9 Oct',
    left: 30,
    category: 'Dairy',
    status: BatchStatus.fresh,
    shelfLeft: 0.85,
    printed: '28 Oct',
    predicted: '27 Oct',
    timeline: '9 Oct Received 30 units',
  ),
];

const _filters = ['All', 'Dairy', 'Produce', 'Meat', 'At risk'];
const _green = Color(0xFF4F9D69);

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  String _filter = 'All';
  String _query = '';
  _Batch _selected = _batches[1];

  List<_Batch> get _visible {
    return _batches.where((b) {
      final matchesFilter = switch (_filter) {
        'All' => true,
        'At risk' => b.status == BatchStatus.atRisk,
        _ => b.category == _filter,
      };
      final q = _query.toLowerCase();
      final matchesSearch = q.isEmpty ||
          b.name.toLowerCase().contains(q) ||
          b.id.toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
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
                'Stock / Batches',
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
              // Search
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.brown),
                decoration: InputDecoration(
                  hintText: 'Search products or batches',
                  hintStyle:
                      TextStyle(color: AppColors.brown.withOpacity(0.5)),
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.brown),
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
              // Filter chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _filters[i];
                    final selected = f == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brown
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.brown),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.cream
                                : AppColors.brown,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sorted by: soonest to spoil',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.brown.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              // Batch list
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No batches found',
                        style: TextStyle(color: AppColors.brown)),
                  ),
                ),
              for (final b in visible) ...[
                _BatchCard(
                  batch: b,
                  selected: b.id == _selected.id,
                  onTap: () => setState(() => _selected = b),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              const Text(
                'BATCH DETAIL (TAP A ROW)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.brown,
                ),
              ),
              const SizedBox(height: 8),
              _DetailCard(batch: _selected),
            ],
          ),
        ),
      ],
    );
  }
}

class _BatchCard extends StatelessWidget {
  final _Batch batch;
  final bool selected;
  final VoidCallback onTap;

  const _BatchCard({
    required this.batch,
    required this.selected,
    required this.onTap,
  });

  Color get _color => switch (batch.status) {
        BatchStatus.atRisk => AppColors.red,
        BatchStatus.useSoon => AppColors.orange,
        BatchStatus.fresh => _green,
      };

  String get _label => switch (batch.status) {
        BatchStatus.atRisk => 'At risk',
        BatchStatus.useSoon => 'Use soon',
        BatchStatus.fresh => 'Fresh',
      };

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 11, color: AppColors.brown);
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
              '${batch.id} · received ${batch.received} · ${batch.left} left',
              style: small,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: batch.shelfLeft,
                minHeight: 6,
                color: _color,
                backgroundColor: AppColors.brown.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Printed: ${batch.printed}', style: small),
                Text('Predicted: ${batch.predicted}', style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final _Batch batch;
  const _DetailCard({required this.batch});

  @override
  Widget build(BuildContext context) {
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
            '${batch.name.split(' ').first} · ${batch.id}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            batch.timeline,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _OutlineButton('Edit qty', onTap: () {}),
              const SizedBox(width: 8),
              _OutlineButton('Log waste', onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
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
