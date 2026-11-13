import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/models/shopping_item.dart';
import 'package:project6/screens/add_recipe_screen.dart';
import 'package:project6/screens/shopping_screen.dart';

void main() {
  // A tall test screen so the whole form is on screen.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Add recipe form shows an error and does not save when name is empty',
          (tester) async {
        useTallScreen(tester);
        var saved = false;
        await tester.pumpWidget(MaterialApp(
          home: AddRecipeScreen(onSave: (Recipe r) async => saved = true),
        ));

        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pump();

        expect(find.text('Recipe name is required.'), findsOneWidget);
        expect(saved, isFalse);
      });

  testWidgets('Add recipe form shows an error when an ingredient has a name but no quantity',
          (tester) async {
        useTallScreen(tester);
        var saved = false;
        await tester.pumpWidget(MaterialApp(
          home: AddRecipeScreen(onSave: (Recipe r) async => saved = true),
        ));

        await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Soup');
        await tester.enterText(find.widgetWithText(TextField, 'Ingredient'), 'carrot');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
        await tester.pump();

        expect(
          find.text('Every ingredient needs a name and a quantity greater than 0.'),
          findsOneWidget,
        );
        expect(saved, isFalse);
      });

  testWidgets('Shopping list screen shows the empty-plan message when there are no items',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ShoppingScreen(itemsStream: Stream.value(<ShoppingItem>[])),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('Your plan is empty. Add meals in the Plan tab, then generate your list.'),
          findsOneWidget,
        );
      });
}