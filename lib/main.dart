import 'package:material_ui/material_ui.dart';

import 'database_helper.dart';
import 'models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PizzaPizzaApp());
}

class PizzaPizzaApp extends StatelessWidget {
  const PizzaPizzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizza Pizza Order Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        scaffoldBackgroundColor: const Color(0xFFFFFAF5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF6A00),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  final TextEditingController _budgetController = TextEditingController(
    text: '25.00',
  );

  // Restaurant data loaded from SQLite.
  List<FoodItem> _foods = [];
  List<OrderPlan> _plans = [];

  // New: food menu searching and category filtering.
  String _menuSearchQuery = '';
  String _selectedMenuCategory = 'All';

  // Planner selections.
  final Set<int> _selectedIds = {};

  // Preserve historical items deleted from the menu.
  final List<PlanItem> _retainedUnavailableItems = [];

  int _tabIndex = 0;
  int? _editingPlanId;

  String _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

  String? _searchedDate;
  OrderPlan? _searchedPlan;

  bool _loading = true;
  bool _searchPerformed = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  // Load menu items and saved orders from SQLite.
  Future<void> _loadData() async {
    try {
      final foods = await _db.getFoodItems();
      final plans = await _db.getAllOrderPlans();

      if (!mounted) return;

      setState(() {
        _foods = foods;
        _plans = plans;

        final validIds = foods.map((e) => e.id).toSet();

        // Preserve deleted items in orders being edited.
        if (_editingPlanId != null) {
          final editingPlans = plans.where((plan) => plan.id == _editingPlanId);

          if (editingPlans.isNotEmpty) {
            final retainedIds = _retainedUnavailableItems
                .map((item) => item.foodId)
                .toSet();

            for (final item in editingPlans.first.items) {
              final id = item.foodId;

              if (id != null &&
                  _selectedIds.contains(id) &&
                  !validIds.contains(id) &&
                  !retainedIds.contains(id)) {
                _retainedUnavailableItems.add(item);
              }
            }
          }
        }

        _selectedIds.removeWhere((id) => !validIds.contains(id));

        // Refresh saved date-search results.
        if (_searchPerformed && _searchedDate != null) {
          OrderPlan? found;

          for (final plan in plans) {
            if (plan.date == _searchedDate) {
              found = plan;
              break;
            }
          }

          _searchedPlan = found;
        }

        // Reset the category filter if its category
        // no longer exists in the food database.
        if (_selectedMenuCategory != 'All' &&
            !foods.any((item) => item.category == _selectedMenuCategory)) {
          _selectedMenuCategory = 'All';
        }

        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  // Show messages at the bottom of the screen.
  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // Calculate the selected total including historical items.
  int get _selectedTotal {
    final currentTotal = _foods
        .where((item) => _selectedIds.contains(item.id))
        .fold<int>(0, (total, item) => total + item.priceCents);

    final historicalTotal = _retainedUnavailableItems.fold<int>(
      0,
      (total, item) => total + item.priceCents,
    );

    return currentTotal + historicalTotal;
  }

  // Ask for confirmation before deleting.
  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Select a date using the calendar.
  Future<String?> _pickDate(String initialDate) async {
    final initial = DateTime.parse(initialDate);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    return date?.toIso8601String().substring(0, 10);
  }

  // Add or update a food item.
  Future<void> _showFoodDialog([FoodItem? item]) async {
    String name = item?.name ?? '';
    String category = item?.category ?? 'Pizza';

    String priceText = item == null
        ? ''
        : (item.priceCents / 100).toStringAsFixed(2);

    String? validationError;

    final values = await showDialog<Map<String, Object>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            return AlertDialog(
              title: Text(item == null ? 'Add Food Item' : 'Update Food Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Food name'),
                      onChanged: (value) {
                        name = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      onChanged: (value) {
                        category = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: priceText,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: '\$',
                      ),
                      onChanged: (value) {
                        priceText = value;
                      },
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        validationError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmedName = name.trim();
                    final trimmedCategory = category.trim();
                    final price = parsePrice(priceText);

                    if (trimmedName.isEmpty ||
                        trimmedCategory.isEmpty ||
                        price == null ||
                        price <= 0) {
                      updateDialog(() {
                        validationError =
                            'Enter a name, category, and '
                            'positive price (maximum 2 decimals).';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, {
                      'name': trimmedName,
                      'category': trimmedCategory,
                      'price': price,
                    });
                  },
                  child: Text(item == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (values == null || !mounted) return;

    try {
      if (item == null) {
        await _db.addFoodItem(
          name: values['name'] as String,
          category: values['category'] as String,
          priceCents: values['price'] as int,
        );
      } else {
        await _db.updateFoodItem(
          id: item.id,
          name: values['name'] as String,
          category: values['category'] as String,
          priceCents: values['price'] as int,
        );
      }

      await _loadData();

      _message(
        item == null
            ? 'Food item added successfully.'
            : 'Food item updated successfully.',
      );
    } catch (error) {
      _message('Could not save food item: $error');
    }
  }

  // Delete food from the SQLite menu.
  Future<void> _deleteFood(FoodItem item) async {
    final confirmed = await _confirm(
      'Delete Food Item',
      'Delete ${item.name} from the menu?',
    );

    if (!confirmed) return;

    try {
      await _db.deleteFoodItem(item.id);
      await _loadData();
      _message('Food item deleted successfully.');
    } catch (error) {
      _message('Could not delete food item: $error');
    }
  }

  // Select food without exceeding the budget.
  void _toggleFood(FoodItem item, bool selected) {
    if (!selected) {
      setState(() {
        _selectedIds.remove(item.id);
      });
      return;
    }

    final budget = parsePrice(_budgetController.text);

    if (budget == null || budget <= 0) {
      _message('Enter a valid target cost first.');
      return;
    }

    if (_selectedTotal + item.priceCents > budget) {
      _message('Budget exceeded! This item cannot be selected.');
      return;
    }

    setState(() {
      _selectedIds.add(item.id);
    });
  }

  // Clear the order planner.
  void _resetPlanner() {
    setState(() {
      _editingPlanId = null;
      _selectedIds.clear();
      _retainedUnavailableItems.clear();

      _selectedDate = DateTime.now().toIso8601String().substring(0, 10);

      _budgetController.text = '25.00';
    });
  }

  // Save or update an order plan.
  Future<void> _savePlan() async {
    final budget = parsePrice(_budgetController.text);

    if (budget == null || budget <= 0) {
      _message('Enter a valid positive daily target cost.');
      return;
    }

    final selectedItems = _foods
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    if (selectedItems.isEmpty && _retainedUnavailableItems.isEmpty) {
      _message('Select at least one food item.');
      return;
    }

    if (_selectedTotal > budget) {
      _message('The selected total exceeds the target cost.');
      return;
    }

    try {
      final existing = await _db.getOrderPlanByDate(_selectedDate);

      if (existing != null && existing.id != _editingPlanId) {
        _message(
          'An order already exists for this date. '
          'Edit the existing order or choose another date.',
        );
        return;
      }

      await _db.saveOrderPlan(
        id: _editingPlanId,
        date: _selectedDate,
        budgetCents: budget,
        selectedItems: selectedItems,
        retainedItems: List<PlanItem>.from(_retainedUnavailableItems),
      );

      if (!mounted) return;

      _resetPlanner();
      await _loadData();

      if (!mounted) return;

      setState(() {
        _tabIndex = 2;
      });

      _message('Order plan saved successfully.');
    } catch (error) {
      _message('Could not save order plan: $error');
    }
  }

  // Edit an existing order and preserve deleted menu items.
  void _editPlan(OrderPlan plan) {
    final availableIds = _foods.map((item) => item.id).toSet();

    final savedIds = plan.items
        .map((item) => item.foodId)
        .whereType<int>()
        .toSet();

    final missingItems = plan.items.where((item) {
      return item.foodId == null || !availableIds.contains(item.foodId);
    }).toList();

    setState(() {
      _editingPlanId = plan.id;
      _selectedDate = plan.date;

      _budgetController.text = (plan.budgetCents / 100).toStringAsFixed(2);

      _selectedIds
        ..clear()
        ..addAll(savedIds.intersection(availableIds));

      _retainedUnavailableItems
        ..clear()
        ..addAll(missingItems);

      _tabIndex = 1;
    });

    if (missingItems.isNotEmpty) {
      _message(
        'Some saved food items are no longer on the menu. '
        'Their original prices have been preserved.',
      );
    }
  }

  // Delete a saved order.
  Future<void> _deletePlan(OrderPlan plan) async {
    final confirmed = await _confirm(
      'Delete Order Plan',
      'Delete the saved order for ${plan.date}?',
    );

    if (!confirmed) return;

    try {
      await _db.deleteOrderPlan(plan.id);

      if (!mounted) return;

      if (_editingPlanId == plan.id) {
        _resetPlanner();
      }

      await _loadData();

      _message('Order plan deleted successfully.');
    } catch (error) {
      _message('Could not delete order plan: $error');
    }
  }

  // Search saved orders by date.
  Future<void> _searchByDate() async {
    final initial =
        _searchedDate ?? DateTime.now().toIso8601String().substring(0, 10);

    final date = await _pickDate(initial);

    if (date == null) return;

    try {
      final result = await _db.getOrderPlanByDate(date);

      if (!mounted) return;

      setState(() {
        _searchedDate = date;
        _searchedPlan = result;
        _searchPerformed = true;
      });
    } catch (error) {
      _message('Search failed: $error');
    }
  }

  // Display a section heading.
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // NEW FEATURE: Search and filter menu items.
  Widget _menuPage() {
    final categories = _foods.map((item) => item.category).toSet().toList()
      ..sort();

    // Apply both searching and category filtering.
    final filteredFoods = _foods.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(
        _menuSearchQuery.toLowerCase().trim(),
      );

      final matchesCategory =
          _selectedMenuCategory == 'All' ||
          item.category == _selectedMenuCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Restaurant heading.
        Card(
          color: const Color(0xFFFFE1CC),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(
                  Icons.local_pizza,
                  color: Colors.deepOrange,
                  size: 62,
                ),
                const SizedBox(height: 8),
                const Text(
                  'PIZZA PIZZA',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB63C00),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your daily food ordering planner',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_foods.length} menu items available',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        _sectionTitle('Food Menu'),

        // Add food functionality remains unchanged.
        FilledButton.icon(
          onPressed: () => _showFoodDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Add Food Item'),
        ),

        const SizedBox(height: 16),

        // NEW: Search by food name.
        TextField(
          onChanged: (value) {
            setState(() {
              _menuSearchQuery = value;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Search Food Items',
            hintText: 'Search for pizza, drinks, sides...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 14),

        // NEW: Category filtering.
        const Text(
          'Filter by Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in ['All', ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _selectedMenuCategory == category,
                    onSelected: (_) {
                      setState(() {
                        _selectedMenuCategory = category;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // NEW: Show the number of matching items.
        Text(
          'Showing ${filteredFoods.length} of '
          '${_foods.length} food items',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 8),

        // Display when no results are found.
        if (filteredFoods.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No food items match your search.',
                textAlign: TextAlign.center,
              ),
            ),
          ),

        // Display the filtered menu.
        for (final item in filteredFoods)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Icon(
                  item.category == 'Drinks'
                      ? Icons.local_drink
                      : item.category == 'Desserts'
                      ? Icons.cake
                      : item.category == 'Pizza'
                      ? Icons.local_pizza
                      : Icons.restaurant,
                  color: Colors.deepOrange,
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.category} • '
                '${formatMoney(item.priceCents)}',
              ),
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Edit food',
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      _showFoodDialog(item);
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete food',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteFood(item);
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Order planner, date picker, budget, and food selection.
  Widget _plannerPage() {
    final budget = parsePrice(_budgetController.text);
    final remaining = (budget ?? 0) - _selectedTotal;

    final overBudget = budget == null || budget <= 0 || _selectedTotal > budget;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(
          _editingPlanId == null ? 'Create Order Plan' : 'Update Order Plan',
        ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Cost Per Day',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () async {
                    final chosen = await _pickDate(_selectedDate);

                    if (chosen != null && mounted) {
                      setState(() {
                        _selectedDate = chosen;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Date: $_selectedDate'),
                ),

                const Divider(height: 28),

                Text(
                  'Selected total: '
                  '${formatMoney(_selectedTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Remaining budget: '
                  '${formatMoney(remaining)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: overBudget ? Colors.red : Colors.green.shade700,
                  ),
                ),

                if (overBudget)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Enter a valid budget that covers '
                      'your selected items.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Preserve historical order items.
        if (_retainedUnavailableItems.isNotEmpty) ...[
          _sectionTitle('Previously Saved Items'),

          const Text(
            'These items are no longer on the menu, '
            'but their saved prices are preserved.',
          ),

          const SizedBox(height: 8),

          for (final item in _retainedUnavailableItems)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history, color: Colors.deepOrange),
                title: Text(item.name),
                subtitle: Text(
                  '${formatMoney(item.priceCents)} '
                  '• Historical item',
                ),
                trailing: IconButton(
                  tooltip: 'Remove historical item',
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _retainedUnavailableItems.remove(item);
                    });
                  },
                ),
              ),
            ),
        ],

        _sectionTitle('Select Food Items'),

        for (final item in _foods)
          Card(
            child: CheckboxListTile(
              value: _selectedIds.contains(item.id),
              activeColor: Colors.deepOrange,
              secondary: const Icon(Icons.fastfood, color: Colors.deepOrange),
              title: Text(item.name),
              subtitle: Text(formatMoney(item.priceCents)),
              onChanged: (checked) {
                _toggleFood(item, checked ?? false);
              },
            ),
          ),

        const SizedBox(height: 14),

        FilledButton.icon(
          onPressed: _savePlan,
          icon: const Icon(Icons.save),
          label: Text(
            _editingPlanId == null ? 'Save Order Plan' : 'Update Order Plan',
          ),
        ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: _resetPlanner,
          icon: const Icon(Icons.refresh),
          label: const Text('Clear / New Plan'),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // Display one saved order with food item snapshots.
  Widget _orderCard(OrderPlan plan) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Date: ${plan.date}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Target Cost: '
              '${formatMoney(plan.budgetCents)}',
            ),

            Text(
              'Order Total: '
              '${formatMoney(plan.totalCents)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const Divider(),

            for (final item in plan.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text(formatMoney(item.priceCents)),
                  ],
                ),
              ),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _editPlan(plan);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _deletePlan(plan);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Search saved orders and display them newest first.
  Widget _savedPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Search Order by Date'),

        FilledButton.icon(
          onPressed: _searchByDate,
          icon: const Icon(Icons.search),
          label: const Text('Choose Date and Search'),
        ),

        const SizedBox(height: 12),

        if (_searchPerformed) ...[
          Text(
            'Search date: $_searchedDate',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          if (_searchedPlan != null)
            _orderCard(_searchedPlan!)
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No order plan found for this date.'),
              ),
            ),
        ],

        _sectionTitle('All Saved Order Plans'),

        const Text('Orders are displayed by date, newest first.'),

        const SizedBox(height: 12),

        if (_plans.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No saved orders yet. '
                'Create your first plan!',
              ),
            ),
          ),

        for (final plan in _plans) _orderCard(plan),
      ],
    );
  }

  // Main application and navigation tabs.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pizza Pizza Planner')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Database error: $_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                        });
                        _loadData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : IndexedStack(
              index: _tabIndex,
              children: [_menuPage(), _plannerPage(), _savedPage()],
            ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Plan Order',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Saved Orders',
          ),
        ],
      ),
    );
  }
}
