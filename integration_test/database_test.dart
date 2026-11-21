import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:pizza_pizza_planner/database_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SQLite seeding, CRUD, searching, and sorting', (tester) async {
    const testFileName = 'pizza_pizza_integration_test.db';

    final testPath = join(await getDatabasesPath(), testFileName);

    // Delete only the dedicated test database.
    await deleteDatabase(testPath);

    final db = DatabaseHelper.testing(testFileName);

    try {
      // TEST 1: Verify automatic seeding of 20 food items.
      var foods = await db.getFoodItems();

      expect(foods.length, 20);

      expect(foods.any((food) => food.name == 'Cheese Pizza'), isTrue);

      // TEST 2: Add a new food item.
      final newFoodId = await db.addFoodItem(
        name: 'Database Test Pizza',
        category: 'Pizza',
        priceCents: 899,
      );

      foods = await db.getFoodItems();

      expect(foods.length, 21);

      var testFood = foods.firstWhere((food) => food.id == newFoodId);

      expect(testFood.name, 'Database Test Pizza');
      expect(testFood.priceCents, 899);

      // TEST 3: Update an existing food item.
      await db.updateFoodItem(
        id: newFoodId,
        name: 'Updated Database Test Pizza',
        category: 'Pizza',
        priceCents: 999,
      );

      foods = await db.getFoodItems();

      testFood = foods.firstWhere((food) => food.id == newFoodId);

      expect(testFood.name, 'Updated Database Test Pizza');

      expect(testFood.priceCents, 999);

      // TEST 4: Create three saved order plans.
      final cheesePizza = foods.firstWhere(
        (food) => food.name == 'Cheese Pizza',
      );

      final garlicBread = foods.firstWhere(
        (food) => food.name == 'Garlic Bread',
      );

      final firstPlanId = await db.saveOrderPlan(
        date: '2026-11-21',
        budgetCents: 2500,
        selectedItems: [cheesePizza, garlicBread],
      );

      await db.saveOrderPlan(
        date: '2026-11-23',
        budgetCents: 3000,
        selectedItems: [cheesePizza],
      );

      await db.saveOrderPlan(
        date: '2026-11-22',
        budgetCents: 2500,
        selectedItems: [garlicBread],
      );

      // TEST 5: Search for an existing order.
      final foundPlan = await db.getOrderPlanByDate('2026-11-21');

      expect(foundPlan, isNotNull);
      expect(foundPlan!.id, firstPlanId);
      expect(foundPlan.budgetCents, 2500);
      expect(foundPlan.totalCents, 1598);
      expect(foundPlan.items.length, 2);

      // TEST 6: Search for a date without an order.
      final missingPlan = await db.getOrderPlanByDate('2026-11-25');

      expect(missingPlan, isNull);

      // TEST 7: Verify descending date order.
      var plans = await db.getAllOrderPlans();

      expect(plans.length, 3);
      expect(plans[0].date, '2026-11-23');
      expect(plans[1].date, '2026-11-22');
      expect(plans[2].date, '2026-11-21');

      // TEST 8: Update an existing order plan.
      await db.saveOrderPlan(
        id: firstPlanId,
        date: '2026-11-21',
        budgetCents: 3000,
        selectedItems: [cheesePizza, garlicBread],
      );

      final updatedPlan = await db.getOrderPlan(firstPlanId);

      expect(updatedPlan, isNotNull);
      expect(updatedPlan!.budgetCents, 3000);
      expect(updatedPlan.totalCents, 1598);

      // TEST 9: Reject an order over the budget.
      await expectLater(
        db.saveOrderPlan(
          date: '2026-11-24',
          budgetCents: 500,
          selectedItems: [cheesePizza],
        ),
        throwsStateError,
      );

      // TEST 10: Delete a food item.
      await db.deleteFoodItem(newFoodId);

      foods = await db.getFoodItems();

      expect(foods.length, 20);

      expect(foods.any((food) => food.id == newFoodId), isFalse);

      // TEST 11: Delete a saved order plan.
      await db.deleteOrderPlan(firstPlanId);

      final deletedPlan = await db.getOrderPlan(firstPlanId);

      expect(deletedPlan, isNull);

      plans = await db.getAllOrderPlans();

      expect(plans.length, 2);

      // TEST 12: Verify data persists after reopening.
      await db.close();

      final reopened = DatabaseHelper.testing(testFileName);

      try {
        final reopenedFoods = await reopened.getFoodItems();

        expect(reopenedFoods.length, 20);

        final reopenedPlans = await reopened.getAllOrderPlans();

        expect(reopenedPlans.length, 2);
      } finally {
        await reopened.close();
      }
    } finally {
      await db.close();

      // Clean up only the integration test database.
      await deleteDatabase(testPath);
    }
  });
}
