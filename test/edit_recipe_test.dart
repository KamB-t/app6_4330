import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project6/models/recipe.dart';
import 'package:project6/screens/add_recipe_screen.dart';

void main() {
  testWidgets('Editing pre-fills the form and keeps id, photo and favorite',
      (tester) async {
    // A tall test screen so the whole form (and the Save button) is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = Recipe(
      id: 'abc',
      name: 'Chicken',
      instructions: 'Cook until done.',
      imageUrl: 'https://example.com/c.jpg',
      isFavorite: true,
      ingredients: [Ingredient(name: 'chicken', qty: 500, unit: 'g')],
    );
    Recipe? saved;

    // The form is pushed from another screen, because saving closes it.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddRecipeScreen(
                  initial: original,
                  onSave: (r) async => saved = r,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit recipe'), findsOneWidget);
    final nameField =
        tester.widget<TextField>(find.widgetWithText(TextField, 'Name'));
    expect(nameField.controller!.text, 'Chicken');

    await tester.enterText(
      find.widgetWithText(TextField, 'Instructions'),
      'Cook 30 minutes, flip, 15 more.',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.id, 'abc');
    expect(saved!.imageUrl, 'https://example.com/c.jpg');
    expect(saved!.isFavorite, isTrue);
    expect(saved!.instructions, 'Cook 30 minutes, flip, 15 more.');
    expect(saved!.ingredients.single.qty, 500);
  });
}
