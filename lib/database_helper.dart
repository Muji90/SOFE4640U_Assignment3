import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initializeDatabase();
    return _database!;
  }

  // Create the database and seed the menu on first installation.
  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'pizza_pizza_orders.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE food_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price_cents INTEGER NOT NULL
              CHECK(price_cents > 0)
          )
        ''');

        await db.execute('''
          CREATE TABLE order_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_date TEXT NOT NULL UNIQUE,
            budget_cents INTEGER NOT NULL
              CHECK(budget_cents > 0)
          )
        ''');

        await db.execute('''
          CREATE TABLE order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER NOT NULL,
            food_id INTEGER,
            item_name TEXT NOT NULL,
            price_cents INTEGER NOT NULL,
            FOREIGN KEY(plan_id)
              REFERENCES order_plans(id) ON DELETE CASCADE
          )
        ''');

        await _seedFoodItems(db);
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // Insert 20 menu items automatically into a new database.
  Future<void> _seedFoodItems(Database db) async {
    final seedItems = <Map<String, Object>>[
      {
        'name': 'Classic Pepperoni Pizza',
        'category': 'Pizza',
        'price_cents': 1299,
      },
      {'name': 'Cheese Pizza', 'category': 'Pizza', 'price_cents': 1099},
      {'name': 'Hawaiian Pizza', 'category': 'Pizza', 'price_cents': 1399},
      {'name': 'Canadian Pizza', 'category': 'Pizza', 'price_cents': 1499},
      {'name': 'Vegetarian Pizza', 'category': 'Pizza', 'price_cents': 1299},
      {'name': 'BBQ Chicken Pizza', 'category': 'Pizza', 'price_cents': 1599},
      {'name': 'Meat Lovers Pizza', 'category': 'Pizza', 'price_cents': 1699},
      {
        'name': 'Spicy Pepperoni Pizza',
        'category': 'Pizza',
        'price_cents': 1399,
      },
      {'name': 'Four Cheese Pizza', 'category': 'Pizza', 'price_cents': 1499},
      {'name': 'Mushroom Pizza', 'category': 'Pizza', 'price_cents': 1199},
      {'name': 'Chicken Wings', 'category': 'Sides', 'price_cents': 1099},
      {'name': 'Garlic Bread', 'category': 'Sides', 'price_cents': 499},
      {'name': 'Cheesy Bread', 'category': 'Sides', 'price_cents': 699},
      {'name': 'French Fries', 'category': 'Sides', 'price_cents': 449},
      {'name': 'Onion Rings', 'category': 'Sides', 'price_cents': 549},
      {'name': 'Caesar Salad', 'category': 'Salads', 'price_cents': 799},
      {'name': 'Garden Salad', 'category': 'Salads', 'price_cents': 699},
      {'name': 'Chocolate Brownie', 'category': 'Desserts', 'price_cents': 399},
      {'name': 'Soft Drink', 'category': 'Drinks', 'price_cents': 249},
      {'name': 'Bottled Water', 'category': 'Drinks', 'price_cents': 199},
    ];

    final batch = db.batch();

    for (final item in seedItems) {
      batch.insert('food_items', item);
    }

    await batch.commit(noResult: true);
  }

  // Get all menu items, ordered by category and name.
  Future<List<FoodItem>> getFoodItems() async {
    final db = await database;

    final rows = await db.query(
      'food_items',
      orderBy: 'category ASC, name ASC',
    );

    return rows.map(FoodItem.fromMap).toList();
  }

  // Add a new food item.
  Future<int> addFoodItem({
    required String name,
    required String category,
    required int priceCents,
  }) async {
    final db = await database;

    return db.insert('food_items', {
      'name': name,
      'category': category,
      'price_cents': priceCents,
    });
  }

  // Update an existing food item.
  Future<int> updateFoodItem({
    required int id,
    required String name,
    required String category,
    required int priceCents,
  }) async {
    final db = await database;

    return db.update(
      'food_items',
      {'name': name, 'category': category, 'price_cents': priceCents},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a food item from the menu.
  Future<int> deleteFoodItem(int id) async {
    final db = await database;

    return db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  // Insert or update an order and its selected food items.
  Future<int> saveOrderPlan({
    int? id,
    required String date,
    required int budgetCents,
    required List<FoodItem> selectedItems,
  }) async {
    if (selectedItems.isEmpty) {
      throw StateError('Select at least one food item.');
    }

    final total = selectedItems.fold<int>(
      0,
      (sum, item) => sum + item.priceCents,
    );

    if (budgetCents <= 0 || total > budgetCents) {
      throw StateError('The order exceeds the target cost.');
    }

    final db = await database;

    return db.transaction((txn) async {
      late final int planId;

      if (id == null) {
        planId = await txn.insert('order_plans', {
          'order_date': date,
          'budget_cents': budgetCents,
        });
      } else {
        final count = await txn.update(
          'order_plans',
          {'order_date': date, 'budget_cents': budgetCents},
          where: 'id = ?',
          whereArgs: [id],
        );

        if (count != 1) {
          throw StateError('Order plan was not found.');
        }

        planId = id;

        await txn.delete(
          'order_items',
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
      }

      for (final item in selectedItems) {
        await txn.insert('order_items', {
          'plan_id': planId,
          'food_id': item.id,
          'item_name': item.name,
          'price_cents': item.priceCents,
        });
      }

      return planId;
    });
  }

  // Load one complete order plan and its saved item details.
  Future<OrderPlan?> getOrderPlan(int id) async {
    final db = await database;

    final rows = await db.query(
      'order_plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final orderRows = await db.query(
      'order_items',
      where: 'plan_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );

    final row = rows.first;

    return OrderPlan(
      id: row['id'] as int,
      date: row['order_date'] as String,
      budgetCents: row['budget_cents'] as int,
      items: orderRows.map(PlanItem.fromMap).toList(),
    );
  }

  // Query a saved order plan by its date.
  Future<OrderPlan?> getOrderPlanByDate(String date) async {
    final db = await database;

    final rows = await db.query(
      'order_plans',
      columns: ['id'],
      where: 'order_date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return getOrderPlan(rows.first['id'] as int);
  }

  // Retrieve all plans in descending date order.
  Future<List<OrderPlan>> getAllOrderPlans() async {
    final db = await database;

    final rows = await db.query(
      'order_plans',
      columns: ['id'],
      orderBy: 'order_date DESC, id DESC',
    );

    final plans = <OrderPlan>[];

    for (final row in rows) {
      final plan = await getOrderPlan(row['id'] as int);

      if (plan != null) {
        plans.add(plan);
      }
    }

    return plans;
  }

  // Delete a saved order and its associated items.
  Future<int> deleteOrderPlan(int id) async {
    final db = await database;

    return db.delete('order_plans', where: 'id = ?', whereArgs: [id]);
  }
}
