import 'package:flutter_test/flutter_test.dart';
import 'package:pizza_pizza_planner/main.dart';

void main() {
  testWidgets('Pizza Pizza app starts correctly', (tester) async {
    await tester.pumpWidget(const PizzaPizzaApp());

    expect(find.text('Pizza Pizza Planner'), findsOneWidget);
  });
}
