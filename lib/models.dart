class FoodItem {
  final int id;
  final String name;
  final String category;
  final int priceCents;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.priceCents,
  });

  factory FoodItem.fromMap(Map<String, Object?> map) {
    return FoodItem(
      id: map['id'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      priceCents: map['price_cents'] as int,
    );
  }
}

class PlanItem {
  final int? foodId;
  final String name;
  final int priceCents;

  const PlanItem({
    required this.foodId,
    required this.name,
    required this.priceCents,
  });

  factory PlanItem.fromMap(Map<String, Object?> map) {
    return PlanItem(
      foodId: map['food_id'] as int?,
      name: map['item_name'] as String,
      priceCents: map['price_cents'] as int,
    );
  }
}

class OrderPlan {
  final int id;
  final String date;
  final int budgetCents;
  final List<PlanItem> items;

  const OrderPlan({
    required this.id,
    required this.date,
    required this.budgetCents,
    required this.items,
  });

  int get totalCents {
    return items.fold(0, (total, item) => total + item.priceCents);
  }
}

String formatMoney(int cents) {
  return '\$${(cents / 100).toStringAsFixed(2)}';
}

// Convert a positive price into integer cents.
int? parsePrice(String input) {
  final value = input.trim();

  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    return null;
  }

  final parts = value.split('.');
  final dollars = int.tryParse(parts[0]);

  if (dollars == null) return null;

  final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';

  final cents = int.tryParse(fraction);

  if (cents == null) return null;

  return dollars * 100 + cents;
}
