double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

/// One batch from GET /batches (also returned by POST and PATCH /batches).
class BatchItem {
  final int id;
  final int productId;
  final String name;
  final String unit;
  final double quantity;
  final String receivedDate; // "2024-06-20"
  final String expiryDate; // last day it can be sold
  final int daysLeft; // negative once expired
  final String status; // active / sold_out / discarded / donated
  final int discountPct;

  const BatchItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.receivedDate,
    required this.expiryDate,
    required this.daysLeft,
    required this.status,
    required this.discountPct,
  });

  factory BatchItem.fromJson(Map<String, dynamic> j) => BatchItem(
        id: _int(j['id']),
        productId: _int(j['product_id']),
        name: j['name']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        quantity: _num(j['quantity']),
        receivedDate: j['received_date']?.toString() ?? '',
        expiryDate: j['expiry_date']?.toString() ?? '',
        daysLeft: _int(j['days_left']),
        status: j['status']?.toString() ?? 'active',
        discountPct: _int(j['discount_pct']),
      );
}

/// One catalogue product from GET /products.
class ProductItem {
  final int productId;
  final String name;
  final String category;
  final int shelfLifeDays;
  final String unit;

  const ProductItem({
    required this.productId,
    required this.name,
    required this.category,
    required this.shelfLifeDays,
    required this.unit,
  });

  factory ProductItem.fromJson(Map<String, dynamic> j) => ProductItem(
        productId: _int(j['product_id']),
        name: j['name']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        shelfLifeDays: _int(j['shelf_life_days']),
        unit: j['unit']?.toString() ?? '',
      );
}
