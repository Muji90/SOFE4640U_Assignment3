import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class DatabaseHelper {
  // Private constructor for the database helper.
  DatabaseHelper._(this._databaseFileName);

  // Main application database.
  static final DatabaseHelper instance = DatabaseHelper._(
    'pizza_pizza_orders.db',
  );

  // Create a separate database for automated testing.
  factory DatabaseHelper.testing(String databaseFileName) {
    if (!databaseFileName.endsWith('.db') ||
        databaseFileName == 'pizza_pizza_orders.db' ||
        databaseFileName.contains('/') ||
        databaseFileName.contains('\\')) {
      throw ArgumentError(
        'Tests must use a separate database filename ending in .db.',
      );
    }

    return DatabaseHelper._(databaseFileName);
  }

  final String _databaseFileName;

  Database? _database;
  Future<Database>? _openingDatabase;

  // Return the existing database or initialize a new connection.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    if (_openingDatabase != null) {
      return _openingDatabase!;
    }

    final opening = _initializeDatabase();
    _openingDatabase = opening;

    try {
      final db = await opening;
      _database = db;
      return db;
    } finally {
      _openingDatabase = null;
    }
  }

  // Close the database connection after testing.
  Future<void> close() async {
    if (_openingDatabase != null) {
      await _openingDatabase;
    }

    final db = _database;
    _database = null;

    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  // Create the database and seed its items on first installation.
  Future<Database> _initializeDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(databasePath, _databaseFileName);

    return openDatabase(
      path,
      version: 1,

      // Enable foreign key constraints.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // Create all three tables when the database is first created.
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
            price_cents INTEGER NOT NULL
              CHECK(price_cents > 0),
            FOREIGN KEY(plan_id)
              REFERENCES order_plans(id) ON DELETE CASCADE
          )
        ''');

        // Automatically insert the initial restaurant menu.
        await _seedFoodItems(db);
      },
    );
  }

  // Seed 20 Pizza Pizza food items into a new database.
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

  // Retrieve all food items ordered by category and name.
  Future<List<FoodItem>> getFoodItems() async {
    final db = await database;

    final rows = await db.query(
      'food_items',
      orderBy: 'category ASC, name ASC',
    );

    return rows.map(FoodItem.fromMap).toList();
  }

  // Add a new food item to the menu.
  Future<int> addFoodItem({
    required String name,
    required String category,
    required int priceCents,
  }) async {
    if (name.trim().isEmpty || category.trim().isEmpty || priceCents <= 0) {
      throw ArgumentError(
        'A food item requires a name, category, and positive price.',
      );
    }

    final db = await database;

    return db.insert('food_items', {
      'name': name.trim(),
      'category': category.trim(),
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
    if (name.trim().isEmpty || category.trim().isEmpty || priceCents <= 0) {
      throw ArgumentError(
        'A food item requires a name, category, and positive price.',
      );
    }

    final db = await database;

    return db.update(
      'food_items',
      {
        'name': name.trim(),
        'category': category.trim(),
        'price_cents': priceCents,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a food item from the menu.
  // Existing order plans retain their saved item snapshots.
  Future<int> deleteFoodItem(int id) async {
    final db = await database;

    return db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  // Save or update an order plan.
  //
  // selectedItems contains current menu selections.
  // retainedItems contains historical items no longer on the menu.
  Future<int> saveOrderPlan({
    int? id,
    required String date,
    required int budgetCents,
    required List<FoodItem> selectedItems,
    List<PlanItem> retainedItems = const [],
  }) async {
    if (selectedItems.isEmpty && retainedItems.isEmpty) {
      throw StateError('Select at least one food item.');
    }

    // Calculate the total of current menu selections.
    final selectedTotal = selectedItems.fold<int>(
      0,
      (sum, item) => sum + item.priceCents,
    );

    // Include historical food prices in the order total.
    final retainedTotal = retainedItems.fold<int>(
      0,
      (sum, item) => sum + item.priceCents,
    );

    final total = selectedTotal + retainedTotal;

    // Ensure no order can exceed its daily spending target.
    if (budgetCents <= 0 || total > budgetCents) {
      throw StateError('The order exceeds the target cost.');
    }

    final db = await database;

    // Transactions ensure that an order and all its items
    // are saved together.
    return db.transaction((txn) async {
      late final int planId;

      if (id == null) {
        // Create a new order plan.
        planId = await txn.insert('order_plans', {
          'order_date': date,
          'budget_cents': budgetCents,
        });
      } else {
        // Update an existing order plan.
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

        // Remove previous selections before saving the
        // updated selection.
        await txn.delete(
          'order_items',
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
      }

      // Store the selected current menu items.
      for (final item in selectedItems) {
        await txn.insert('order_items', {
          'plan_id': planId,
          'food_id': item.id,
          'item_name': item.name,
          'price_cents': item.priceCents,
        });
      }

      // Store historical items with their original names
      // and prices.
      for (final item in retainedItems) {
        await txn.insert('order_items', {
          'plan_id': planId,
          'food_id': null,
          'item_name': item.name,
          'price_cents': item.priceCents,
        });
      }

      return planId;
    });
  }

  // Retrieve one complete saved order plan.
  Future<OrderPlan?> getOrderPlan(int id) async {
    final db = await database;

    final rows = await db.query(
      'order_plans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    // Retrieve the items belonging to this order.
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

  // Search for a saved order plan by its date.
  Future<OrderPlan?> getOrderPlanByDate(String date) async {
    final db = await database;

    final rows = await db.query(
      'order_plans',
      columns: ['id'],
      where: 'order_date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return getOrderPlan(rows.first['id'] as int);
  }

  // Retrieve saved order plans in descending date order.
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

  // Delete an order plan and its associated items.
  // Foreign key cascading removes the related order_items.
  Future<int> deleteOrderPlan(int id) async {
    final db = await database;

    return db.delete('order_plans', where: 'id = ?', whereArgs: [id]);
  }
}
